import AppKit
import PaneFlipCore

// Undocumented CoreGraphics Services calls: which desktop (Space) a display or window is on.
@_silgen_name("CGSMainConnectionID")
private func CGSMainConnectionID() -> Int32

@_silgen_name("CGSManagedDisplayGetCurrentSpace")
private func CGSManagedDisplayGetCurrentSpace(_ cid: Int32, _ displayUUID: CFString) -> UInt64

@_silgen_name("CGSCopyManagedDisplaySpaces")
private func CGSCopyManagedDisplaySpaces(_ cid: Int32) -> CFArray?

@_silgen_name("CGSCopySpacesForWindows")
private func CGSCopySpacesForWindows(_ cid: Int32, _ mask: Int32, _ wids: CFArray) -> CFArray?

final class CGSScreenProvider: ScreenProviding {
    /// The Dock, found once (looking for it costs Launch Services calls at every look) and again only after it quit.
    private var dockApp: NSRunningApplication?

    /// The answers of `screens()` and `dockRect()` are kept for a moment: they cost calls to the window server and to the Dock (which answers over Accessibility,
    /// slowly at times), and the zones, the island and the shortcuts ask for them several times a second. A change of the displays or of the desktop forgets them at once.
    private static let freshFor: TimeInterval = 0.2
    private let cacheLock = NSLock()
    private var cachedScreens: (at: TimeInterval, screens: [ScreenInfo])?
    private var cachedDock: (at: TimeInterval, rect: CGRect?)?
    /// The UUID of each display, made once (the monitor asks four times a second); forgotten with the rest when the displays change.
    private var uuids: [CGDirectDisplayID: String] = [:]
    /// Whether Mission Control showed at the last look, for the windows the system listed then: the same list gives the same answer.
    private var missionControl: (windows: [CGWindowID], active: Bool)?
    private var windowRects: (windows: [CGWindowID], at: TimeInterval, facts: (rects: [CGRect], menuOpen: Bool))?
    private var observers: [NSObjectProtocol] = []

    init() {
        let forget: (Notification) -> Void = { [weak self] _ in
            self?.cacheLock.lock()
            self?.cachedScreens = nil
            self?.cachedDock = nil
            self?.uuids = [:]
            self?.cacheLock.unlock()
        }
        observers = [NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: nil, using: forget),
                     NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: nil, using: forget)]
    }

    deinit { observers.forEach { NotificationCenter.default.removeObserver($0); NSWorkspace.shared.notificationCenter.removeObserver($0) } }

    private var primaryHeight: CGFloat { NSScreen.screens.first?.frame.height ?? 0 }

    func flip(_ r: CGRect) -> CGRect {
        CGRect(x: r.minX, y: primaryHeight - r.maxY, width: r.width, height: r.height)
    }

    var pointerCocoa: CGPoint { NSEvent.mouseLocation }

    var pointerAX: CGPoint {
        let m = NSEvent.mouseLocation
        return CGPoint(x: m.x, y: primaryHeight - m.y)
    }

    var menuBarThickness: CGFloat { NSStatusBar.system.thickness }

    func menuBarHeight(of screen: ScreenInfo) -> CGFloat {
        let native = NSScreen.screens.first { $0.frame == screen.cocoaFrame }
        return ceil(max(native.map { $0.frame.maxY - $0.visibleFrame.maxY } ?? 0, screen.notchHeight, menuBarThickness))
    }

    /// While either is open the window manager keeps a shield window over a whole display, at layer 19. Its name is
    /// not used: other apps' window names are only readable with the Screen Recording permission. The size check
    /// keeps the window manager's smaller windows (Stage Manager's strip, for one) from counting.
    var isMissionControlActive: Bool {
        let windows = CGWindowNumbers.ids(.optionOnScreenOnly)
        cacheLock.lock()
        let kept = missionControl.flatMap { $0.windows == windows ? $0.active : nil }
        cacheLock.unlock()
        if let kept { return kept }
        let active = lookForMissionControl()
        cacheLock.lock()
        missionControl = (windows, active)
        cacheLock.unlock()
        return active
    }

    var isPointerOverWallpaper: Bool {
        let rects = windowFacts().rects, point = pointerAX
        return !rects.contains { $0.contains(point) }
    }

    var isMenuOrDockInUse: Bool { windowFacts().menuOpen }

    /// What the window list says, kept while the windows are the same (the numbers alone cost a tenth of a millisecond, the list with a description of each window about a
    /// millisecond, and this is asked at every move of the pointer over a launcher) and for at most half a second (a window may be moved or resized without a number changing).
    private func windowFacts() -> (rects: [CGRect], menuOpen: Bool) {
        let now = ProcessInfo.processInfo.systemUptime, windows = CGWindowNumbers.ids(.optionOnScreenOnly)
        cacheLock.lock()
        let kept = windowRects.flatMap { $0.windows == windows && now - $0.at < 0.5 ? $0.facts : nil }
        cacheLock.unlock()
        if let kept { return kept }
        let made = lookForWindowFacts()
        cacheLock.lock()
        windowRects = (windows, now, made)
        cacheLock.unlock()
        return made
    }

    /// The rectangles of the windows of every app that stand over the wallpaper, in the Accessibility coordinates the window list uses (the app's own too: its menus and popovers
    /// count, but not the large clear panels it lays over a display, which let the mouse through), and whether a menu or the Dock is in use: a window above the ordinary
    /// ones that is neither in the menu bar's strip (the icons) nor a clear panel over a whole display (the Dock's own), nor a panel this app draws itself.
    private func lookForWindowFacts() -> (rects: [CGRect], menuOpen: Bool) {
        guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] else { return ([], false) }
        let me = ProcessInfo.processInfo.processIdentifier
        var rects: [CGRect] = [], menuOpen = false
        for window in list {
            guard (window[kCGWindowAlpha as String] as? Double ?? 1) > 0, let bounds = window[kCGWindowBounds as String] as? [String: CGFloat],
                  let x = bounds["X"], let y = bounds["Y"], let w = bounds["Width"], let h = bounds["Height"] else { continue }
            let layer = window[kCGWindowLayer as String] as? Int ?? -1, owner = window[kCGWindowOwnerName as String] as? String ?? "", rect = CGRect(x: x, y: y, width: w, height: h)
            let own = (window[kCGWindowOwnerPID as String] as? Int32) == me
            if layer >= 0, !["Dock", "Window Server"].contains(owner), !(own && (w >= 1000 || h >= 1000)) { rects.append(rect) }
            guard !menuOpen, MenuWindowRule.isMenu(layer: layer, owner: owner, rect: rect) else { continue }
            // Of this app's own windows only its menus and popovers (a panel it draws itself, such as the island's, is neither): a menu is drawn by the system and
            // is not among the windows of the app, a popover is a window of a class of its own.
            if own, let known = (window[kCGWindowNumber as String] as? Int).flatMap({ NSApp.window(withWindowNumber: $0) }),
               !["Menu", "Popover", "PopUp"].contains(where: { String(describing: type(of: known)).contains($0) }) { continue }
            menuOpen = true
        }
        return (rects, menuOpen)
    }

    private func lookForMissionControl() -> Bool {
        guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] else { return false }
        let displays = NSScreen.screens.map(\.frame.size)
        return list.contains {
            guard ($0[kCGWindowOwnerName as String] as? String) == "WindowManager",
                  ($0[kCGWindowLayer as String] as? Int) == 19,
                  let bounds = $0[kCGWindowBounds as String] as? [String: CGFloat],
                  let w = bounds["Width"], let h = bounds["Height"] else { return false }
            return displays.contains { $0.width == w && $0.height == h }
        }
    }

    /// The Dock itself says it stands on a connected display (or it hides). The system's usable area is no sign: it stays unchanged while the Dock
    /// lands, and a missing answer from the Dock (it does not answer while it moves) means it has not landed.
    var isDockSettled: Bool {
        if CFPreferencesCopyAppValue("autohide" as CFString, "com.apple.dock" as CFString) as? Bool ?? false { return true }
        return dockRect().map { dock in NSScreen.screens.contains { flip($0.frame).intersects(dock) } } ?? false
    }

    func screens() -> [ScreenInfo] {
        let now = ProcessInfo.processInfo.systemUptime
        cacheLock.lock()
        let kept = cachedScreens.flatMap { now - $0.at < Self.freshFor ? $0.screens : nil }
        cacheLock.unlock()
        if let kept { return kept }
        let made = makeScreens()
        cacheLock.lock()
        cachedScreens = (now, made)
        cacheLock.unlock()
        return made
    }

    private func makeScreens() -> [ScreenInfo] {
        let conn = CGSMainConnectionID()
        let dock = dockRect()
        let managed = CGSCopyManagedDisplaySpaces(conn) as? [[String: Any]] ?? []   // once for every display
        dockHome.update(displays: Set(NSScreen.screens.map(displayUUID)),
                        dockDisplay: dock.flatMap { dock in NSScreen.screens.first { flip($0.frame).intersects(dock) }.map(displayUUID) })
        return NSScreen.screens.map { s in
            let uuid = displayUUID(s)
            let space = CGSManagedDisplayGetCurrentSpace(conn, uuid as CFString)
            let legacy = "\(uuid)|\(space)"
            let desktops = ordinaryDesktops(onDisplay: uuid, in: managed)
            let position = desktops.firstIndex(of: space).map { $0 + 1 }
            let tray = uuid == dockHome.phantom ? missedDock(on: s) : dock
            let usable = DockArea.excluding(tray.map { reserved($0, on: s) }, from: flip(s.visibleFrame), onDisplay: flip(s.frame))
            let notch = notch(of: s)
            return ScreenInfo(key: position.map { "\(uuid)|d\($0)" } ?? legacy, name: s.localizedName, size: s.frame.size,
                              cocoaFrame: s.frame, cocoaVisibleFrame: flip(usable), axVisible: usable,
                              legacyKey: legacy, desktopCount: desktops.count, desktopsBefore: desktopsBefore(display: uuid, in: managed), notchWidth: notch.width, notchHeight: notch.height,
                              physicalSize: physicalSize(of: s))
        }
    }

    /// The size of the display in millimetres, as the display tells the system (zero when it does not).
    private func physicalSize(of s: NSScreen) -> CGSize {
        guard let number = s.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else { return .zero }
        return CGDisplayScreenSize(CGDirectDisplayID(number.uint32Value))
    }

    private var dockHome = DockHome()

    /// A display that was unplugged with the Dock on it and has come back while the Dock stayed on the other one is laid out as if the Dock still stood
    /// there: a stand-in for the Dock, widened to the strip the system keeps free (see `reserved`). Nothing without such a strip (the Dock hides, or was
    /// never seen on a display).
    private func missedDock(on s: NSScreen) -> CGRect? {
        guard lastStrip != nil, !(CFPreferencesCopyAppValue("autohide" as CFString, "com.apple.dock" as CFString) as? Bool ?? false) else { return nil }
        return DockArea.standIn(orientation: CFPreferencesCopyAppValue("orientation" as CFString, "com.apple.dock" as CFString) as? String, onDisplay: flip(s.frame))
    }

    /// How much the system keeps free along the Dock's edge, learnt while the Dock stands on a display and the system has made room for it.
    private var lastStrip: CGFloat?

    /// The strip the system keeps free along the Dock's edge (the tray stands a few points inside it, or outside). After a display was unplugged the system
    /// does not make that room on the display the Dock lands on, so the strip learnt earlier is used.
    private func reserved(_ dock: CGRect, on s: NSScreen) -> CGRect {
        let display = flip(s.frame)
        guard dock.intersects(display) else { return dock }
        let orientation = CFPreferencesCopyAppValue("orientation" as CFString, "com.apple.dock" as CFString) as? String
        let inset: CGFloat
        switch orientation {
        case "left": inset = s.visibleFrame.minX - s.frame.minX
        case "right": inset = s.frame.maxX - s.visibleFrame.maxX
        default: inset = s.visibleFrame.minY - s.frame.minY
        }
        if inset > 0 { lastStrip = inset }
        guard let strip = lastStrip else { return dock }
        return DockArea.reserved(dock, strip: strip, orientation: orientation, onDisplay: display)
    }

    /// The notch of a display: what lies between the two usable parts of the top edge, and how far down it reaches; zero without one.
    private func notch(of screen: NSScreen) -> (width: CGFloat, height: CGFloat) {
        #if DEBUG
        // To try the app without a notched display: PANEFLIP_FAKE_NOTCH=1 (or =<width>x<height>), or the default PaneFlipFakeNotch, gives the built-in display one
        // (the main display when there is no built-in one).
        if let fake = Self.fakeNotch, Self.hostsFakeNotch(screen) {
            // Without a height of its own the notch is as tall as the menu bar, as on a notched display.
            return (fake.width, fake.height > 0 ? fake.height : max(screen.frame.maxY - screen.visibleFrame.maxY, menuBarThickness))
        }
        #endif
        guard screen.safeAreaInsets.top > 0, let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea else { return (0, 0) }
        return (max(0, screen.frame.width - left.width - right.width), screen.safeAreaInsets.top)
    }

    #if DEBUG
    /// The display that gets the fake notch: the built-in one, else the first, and only one without a real notch.
    static func hostsFakeNotch(_ screen: NSScreen) -> Bool {
        let builtIn = NSScreen.screens.first {
            ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber).map { CGDisplayIsBuiltin($0.uint32Value) != 0 } ?? false
        }
        return fakeNotch != nil && screen == (builtIn ?? NSScreen.screens.first) && screen.safeAreaInsets.top == 0
    }

    static let fakeNotch: (width: CGFloat, height: CGFloat)? = {
        // From the scheme's environment (PANEFLIP_FAKE_NOTCH) or, without touching the scheme, from the app's defaults (PaneFlipFakeNotch).
        guard let value = ProcessInfo.processInfo.environment["PANEFLIP_FAKE_NOTCH"] ?? UserDefaults.standard.string(forKey: "PaneFlipFakeNotch"), !value.isEmpty, value != "0" else { return nil }
        let sizes = value.lowercased().split(separator: "x").compactMap { Double($0) }.map { CGFloat($0) }
        return sizes.count == 2 ? (sizes[0], sizes[1]) : (200, 0)
    }()
    #endif

    /// The Dock's tray in top-left-origin coordinates while the Dock is showing. After a display was unplugged the
    /// Dock lands on the remaining one before the system's usable area of that display has made room for it (it
    /// stayed unchanged for as long as the Dock was there), so the Dock is asked for itself.
    private func dockRect() -> CGRect? {
        let now = ProcessInfo.processInfo.systemUptime
        cacheLock.lock()
        let kept = cachedDock.flatMap { now - $0.at < Self.freshFor ? $0 : nil }
        cacheLock.unlock()
        if let kept { return kept.rect }
        let made = askDock()
        cacheLock.lock()
        cachedDock = (now, made)
        cacheLock.unlock()
        return made
    }

    private func askDock() -> CGRect? {
        let hides = CFPreferencesCopyAppValue("autohide" as CFString, "com.apple.dock" as CFString) as? Bool ?? false
        if dockApp?.isTerminated != false { dockApp = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first }
        guard !hides, let dock = dockApp else { return nil }
        var children: CFTypeRef?
        guard AXUIElementCopyAttributeValue(AXUIElementCreateApplication(dock.processIdentifier), kAXChildrenAttribute as CFString,
                                            &children) == .success,
              let list = (children as? [AXUIElement])?.first(where: { element in
                  var role: CFTypeRef?
                  return AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role) == .success
                      && (role as? String) == kAXListRole
              }) else { return nil }
        var position: CFTypeRef?, size: CFTypeRef?
        var origin = CGPoint.zero, extent = CGSize.zero
        guard AXUIElementCopyAttributeValue(list, kAXPositionAttribute as CFString, &position) == .success,
              AXUIElementCopyAttributeValue(list, kAXSizeAttribute as CFString, &size) == .success,
              let position, let size,
              AXValueGetValue(position as! AXValue, .cgPoint, &origin),
              AXValueGetValue(size as! AXValue, .cgSize, &extent), extent.width > 0, extent.height > 0 else { return nil }
        return CGRect(origin: origin, size: extent)
    }

    /// The display's ordinary desktops in order (full-screen spaces are not counted); a desktop's 1-based place among
    /// them is what tells it apart.
    private func ordinaryDesktops(onDisplay uuid: String, in displays: [[String: Any]]) -> [UInt64] {
        guard let display = displays.first(where: { ($0["Display Identifier"] as? String)?.caseInsensitiveCompare(uuid) == .orderedSame }),
              let spaces = display["Spaces"] as? [[String: Any]] else { return [] }
        return spaces.filter { ($0["type"] as? Int ?? 0) == 0 }.compactMap { ($0["ManagedSpaceID"] as? NSNumber)?.uint64Value }
    }

    /// The ordinary desktops of the displays the system lists before this one.
    private func desktopsBefore(display uuid: String, in displays: [[String: Any]]) -> Int {
        let ids = displays.compactMap { $0["Display Identifier"] as? String }
        guard let place = ids.firstIndex(where: { $0.caseInsensitiveCompare(uuid) == .orderedSame }) else { return 0 }
        return ids[..<place].reduce(0) { $0 + ordinaryDesktops(onDisplay: $1, in: displays).count }
    }

    func currentSpaceIDs() -> Set<UInt64> {
        let conn = CGSMainConnectionID()
        return Set(NSScreen.screens.map { CGSManagedDisplayGetCurrentSpace(conn, displayUUID($0) as CFString) })
    }

    func spaces(ofWindow id: CGWindowID) -> Set<UInt64> {
        let list = CGSCopySpacesForWindows(CGSMainConnectionID(), 7, [NSNumber(value: id)] as CFArray) as? [NSNumber] ?? []
        return Set(list.map(\.uint64Value))
    }

    private func displayUUID(_ s: NSScreen) -> String {
        guard let num = s.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else { return "unknown" }
        let number = CGDirectDisplayID(num.uint32Value)
        cacheLock.lock()
        let kept = uuids[number]
        cacheLock.unlock()
        if let kept { return kept }
        let made = makeUUID(number)
        if made != "unknown" {
            cacheLock.lock()
            uuids[number] = made
            cacheLock.unlock()
        }
        return made
    }

    private func makeUUID(_ number: CGDirectDisplayID) -> String {
        guard let cfUUID = CGDisplayCreateUUIDFromDisplayID(number)?.takeRetainedValue(),
              let str = CFUUIDCreateString(nil, cfUUID) as String?
        else { return "unknown" }
        return str
    }
}
