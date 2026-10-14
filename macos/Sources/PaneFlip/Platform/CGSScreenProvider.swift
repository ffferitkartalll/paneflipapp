import AppKit

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

    /// While either is open the window manager keeps a shield window over a whole display, at layer 19. Its name is
    /// not used: other apps' window names are only readable with the Screen Recording permission. The size check
    /// keeps the window manager's smaller windows (Stage Manager's strip, for one) from counting.
    var isMissionControlActive: Bool {
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

    func screens() -> [ScreenInfo] {
        let conn = CGSMainConnectionID()
        let dock = dockRect()
        return NSScreen.screens.map { s in
            let uuid = displayUUID(s)
            let space = CGSManagedDisplayGetCurrentSpace(conn, uuid as CFString)
            let legacy = "\(uuid)|\(space)"
            let position = desktopPosition(of: space, onDisplay: uuid)
            let usable = DockArea.excluding(dock, from: flip(s.visibleFrame), onDisplay: flip(s.frame))
            return ScreenInfo(key: position.map { "\(uuid)|d\($0)" } ?? legacy, name: s.localizedName, size: s.frame.size,
                              cocoaFrame: s.frame, cocoaVisibleFrame: flip(usable), axVisible: usable,
                              legacyKey: legacy)
        }
    }

    /// The Dock's tray in top-left-origin coordinates while the Dock is showing. After a display was unplugged the
    /// Dock lands on the remaining one before the system's usable area of that display has made room for it (it
    /// stayed unchanged for as long as the Dock was there), so the Dock is asked for itself.
    private func dockRect() -> CGRect? {
        let hides = CFPreferencesCopyAppValue("autohide" as CFString, "com.apple.dock" as CFString) as? Bool ?? false
        guard !hides, let dock = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first else { return nil }
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

    /// The 1-based place of a desktop among the display's ordinary desktops (full-screen spaces are not counted),
    /// or nil for a space that is not one of them.
    private func desktopPosition(of space: UInt64, onDisplay uuid: String) -> Int? {
        guard let displays = CGSCopyManagedDisplaySpaces(CGSMainConnectionID()) as? [[String: Any]],
              let display = displays.first(where: { ($0["Display Identifier"] as? String)?.caseInsensitiveCompare(uuid) == .orderedSame }),
              let spaces = display["Spaces"] as? [[String: Any]] else { return nil }
        let ordinary = spaces.filter { ($0["type"] as? Int ?? 0) == 0 }.compactMap { ($0["ManagedSpaceID"] as? NSNumber)?.uint64Value }
        return ordinary.firstIndex(of: space).map { $0 + 1 }
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
        guard let num = s.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber,
              let cfUUID = CGDisplayCreateUUIDFromDisplayID(CGDirectDisplayID(num.uint32Value))?.takeRetainedValue(),
              let str = CFUUIDCreateString(nil, cfUUID) as String?
        else { return "unknown" }
        return str
    }
}
