import AppKit
import ObjectiveC
import PaneFlipCore

// Undocumented CoreGraphics Services call: lets this app set the cursor while another app is the active one.
@_silgen_name("CGSMainConnectionID")
private func CGSMainConnectionID() -> Int32

@_silgen_name("CGSSetConnectionProperty")
@discardableResult
private func CGSSetConnectionProperty(_ cid: Int32, _ target: Int32, _ key: CFString, _ value: CFTypeRef) -> Int32

/// The pill of one zone, a floating panel: a toolbar item group, so it is the system's own Liquid Glass segmented
/// control (the one app toolbars use, with its own animations), with the windows of the zone as segments.
/// Click-through until the presenter shows it.
final class PillPanel: NSPanel, NSToolbarDelegate {
    private let stack: ZoneStack
    private let settings: AppSettings
    private let iconFont: IconFont
    private let select: (CGWindowID) -> Void
    private let move: (CGWindowID, Int) -> Void
    private let hide: () -> Void
    /// Where the right button went down, and whether it has moved since: a press that did not move is a click.
    private var rightDownX: CGFloat = 0
    private var rightMoved = false
    private var carriedID: CGWindowID?
    /// What is known when a tab is picked up, in screen coordinates: the distance from the segment's left edge to the
    /// pointer, where the segments start, their height and each one's width. Segments keep their widths, so the
    /// layout for any order follows from these without asking the control again.
    private struct Carry {
        let grab: CGFloat
        let origin: CGFloat
        let y: CGFloat
        let height: CGFloat
        let widths: [CGWindowID: CGFloat]
    }
    private var carry: Carry?
    /// Counts presses, so the safety net in `.rightMouseUp` ends only the press it was set for.
    private var pressCount = 0
    private var carryPausedUntil = Date.distantPast
    private let slide = PillSlide()
    private static let slideDuration: TimeInterval = 0.22
    /// What the system control adds around a segment's text, in points.
    private static let segmentPadding: CGFloat = 22
    private let groupID = NSToolbarItem.Identifier("tabs")
    private var group: NSToolbarItemGroup?
    private var shownKey = ""
    private weak var styledControl: NSSegmentedControl?
    /// Set by the width swizzle: the width it estimated for the control, and the correction measured since.
    fileprivate var estimatedWidth: CGFloat = 0
    fileprivate var widthCorrection: CGFloat = 0
    private var styledName: String?
    private var measured: (key: String, width: CGFloat)?
    /// Set when the toolbar was just built: its segments are measured once they are laid out, not on every tick.
    private var fitPending = false

    init(stack: ZoneStack, settings: AppSettings, iconFont: IconFont,
         select: @escaping (CGWindowID) -> Void, move: @escaping (CGWindowID, Int) -> Void, hide: @escaping () -> Void) {
        self.stack = stack
        self.settings = settings
        self.iconFont = iconFont
        self.select = select
        self.move = move
        self.hide = hide
        _ = Self.looksActive
        _ = Self.setsCursorInBackground
        _ = Self.fitsSegments
        super.init(contentRect: NSRect(x: 0, y: 0, width: 100, height: PillMetrics.height),
                   styleMask: [.titled, .fullSizeContentView, .nonactivatingPanel], backing: .buffered, defer: false)
        level = .floating
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        for button in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] { standardWindowButton(button)?.isHidden = true }
        hasShadow = false
        isOpaque = false
        backgroundColor = .clear
        alphaValue = 0
        ignoresMouseEvents = true
        minSize = NSSize(width: 1, height: 1)
        // A titled window can be dragged by its title bar and toolbar; the pill sits where the presenter puts it.
        isMovable = false
        isMovableByWindowBackground = false
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
    }

    /// The pointing hand while a segment is being carried: the right button is held and the pointer has moved.
    /// The arrow again once the button is released.
    private var cursor: NSCursor { carriedID != nil && rightMoved ? .pointingHand : .arrow }

    private var cursorTimer: Timer?
    private var cursorHeldUntil = Date.distantPast
    /// The active app sets its own cursor on every pointer move too, so a single set flickers between the two.
    /// Setting ours again every millisecond for a moment after each move keeps the hand on top.
    private func holdCursor() {
        cursor.set()
        cursorHeldUntil = Date().addingTimeInterval(0.25)
        guard cursorTimer == nil else { return }
        let timer = Timer(timeInterval: 0.001, repeats: true) { [weak self] timer in
            guard let self, Date() < self.cursorHeldUntil else { timer.invalidate(); self?.cursorTimer = nil; return }
            self.cursor.set()
        }
        RunLoop.main.add(timer, forMode: .common)
        cursorTimer = timer
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    /// Right button: the system control is driven by a left press and drag, so its Liquid Glass lens and scrubbing
    /// behave exactly as they do for the left button. The right button's events are re-posted as left button events
    /// at the same place (the system control only follows events from the real input stream), and while one is in
    /// progress the pressed tab is carried to the segment under the pointer instead of the window being selected.
    override func sendEvent(_ event: NSEvent) {
        let left: CGEventType
        switch event.type {
        case .leftMouseDown:
            stack.interacting = true
            pressCount += 1
            return super.sendEvent(event)
        case .rightMouseDown:
            guard let index = segmentIndex(at: event) else { return }
            stack.interacting = true
            pressCount += 1
            rightDownX = convertPoint(toScreen: event.locationInWindow).x
            rightMoved = false
            let frames = frames()
            carriedID = stack.tabs[index].id
            carry = Carry(grab: convertPoint(toScreen: event.locationInWindow).x - frames[index].minX, origin: frames[0].minX,
                          y: frames[0].minY, height: frames[0].height,
                          widths: Dictionary(uniqueKeysWithValues: zip(stack.tabs.map(\.id), frames.map(\.width))))
            left = .leftMouseDown
        case .rightMouseDragged:
            left = .leftMouseDragged
            if abs(convertPoint(toScreen: event.locationInWindow).x - rightDownX) > 3 { rightMoved = true }
            holdCursor()
        case .rightMouseUp:
            left = .leftMouseUp
            // The press normally ends with the re-posted left button release; if that never comes back, end it here.
            let press = pressCount
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                if let self, self.pressCount == press { self.endPress() }
            }
        case .leftMouseUp:
            super.sendEvent(event)
            return endPress()
        default: return super.sendEvent(event)
        }
        guard carriedID != nil else { return }
        let screen = convertPoint(toScreen: event.locationInWindow)
        let top = NSScreen.screens.first?.frame.height ?? 0
        CGEvent(mouseEventSource: nil, mouseType: left, mouseCursorPosition: CGPoint(x: screen.x, y: top - screen.y),
                mouseButton: .left)?.post(tap: .cghidEventTap)
        if left == .leftMouseDragged { carryTab(toX: screen.x) }
        // A right click that did not move hides the pill, like a double tap of Left Shift.
        if left == .leftMouseUp, !rightMoved { hide() }
    }

    private func endPress() {
        stack.interacting = false
        carriedID = nil
        carry = nil
        holdCursor()
    }

    /// While the pressed tab is dragged it steps over a neighbour once its leading edge has passed the neighbour's
    /// middle: the left edge going left, the right edge going right. The edges are worked out from the segments'
    /// known widths laid end to end, so they depend on the pointer only. Going back needs the same distance again
    /// (plus a small margin), so the tabs cannot swap back and forth on their own.
    private func carryTab(toX x: CGFloat) {
        guard let carried = carriedID, let carry, Date() >= carryPausedUntil,
              let current = stack.tabs.firstIndex(where: { $0.id == carried }) else { return }
        let width = carry.widths[carried] ?? 0
        let leading = x - carry.grab, trailing = leading + width
        let frames = layout(of: stack.tabs, carry)
        let margin: CGFloat = 4
        var target = current
        while target > 0, let neighbour = frames[stack.tabs[target - 1].id], leading < neighbour.midX - margin { target -= 1 }
        if target == current {
            while target < stack.tabs.count - 1, let neighbour = frames[stack.tabs[target + 1].id],
                  trailing > neighbour.midX + margin { target += 1 }
        }
        guard target != current else { return }
        reorder(carried, to: target)
        carryPausedUntil = Date().addingTimeInterval(Self.slideDuration)
    }

    /// Where each tab's segment is for a given order: the known widths end to end from the first segment's edge.
    private func layout(of tabs: [ZoneStack.Tab], _ carry: Carry) -> [CGWindowID: NSRect] {
        var x = carry.origin
        var result: [CGWindowID: NSRect] = [:]
        for tab in tabs {
            let width = carry.widths[tab.id] ?? 0
            result[tab.id] = NSRect(x: x, y: carry.y, width: width, height: carry.height)
            x += width
        }
        return result
    }

    /// Moves the carried tab and shows the segments sliding to their new places. The system control cannot animate
    /// a change of titles, so while the labels slide the real segments hold blank space as wide as their text.
    private func reorder(_ id: CGWindowID, to index: Int) {
        slide.finish()
        let before = stack.tabs
        move(id, index)
        guard let carry, let frameView = contentView?.superview, let group else { return retitleSegments() }
        let old = layout(of: before, carry), new = layout(of: stack.tabs, carry)
        let items = stack.tabs.compactMap { tab -> PillSlide.Item? in
            guard let from = old[tab.id], let to = new[tab.id] else { return nil }
            return .init(name: shownName(tab), icon: iconFont.image(bundleID: tab.bundleID, appName: tab.appName, icon: tab.icon ?? NSWorkspace.shared.icon(for: .applicationBundle), size: 18),
                         from: frameView.convert(convertFromScreen(from), from: nil),
                         to: frameView.convert(convertFromScreen(to), from: nil))
        }
        shownKey = currentKey()
        let space = NSString("\u{2007}").size(withAttributes: [.font: NSFont.systemFont(ofSize: 13)]).width
        for (subitem, tab) in zip(group.subitems, stack.tabs) {
            let width = carry.widths[tab.id] ?? 0
            subitem.title = String(repeating: "\u{2007}", count: max(1, Int(((width - Self.segmentPadding) / space).rounded())))
        }
        let content = settings.values.pillContent
        slide.run(items, showsIcon: content != .name, showsName: content != .icon, in: frameView,
                  duration: Self.slideDuration) { [weak self] in self?.retitleSegments() }
    }

    private func frames() -> [NSRect] {
        guard let frameView = contentView?.superview, let control = Self.segmentedControl(in: frameView) else { return [] }
        return Self.segmentFrames(under: control)
    }

    /// Rewrites the titles of the existing segments in the stack's order. The toolbar is not rebuilt: that would end
    /// the press the system control is tracking.
    private func retitleSegments() {
        shownKey = currentKey()
        if let group { zip(group.subitems, titles()).forEach { $0.title = $1 } }
    }

    /// The segment under the pointer (the nearest end when it is past the last one), by the control's real frames.
    private func segmentIndex(at event: NSEvent) -> Int? {
        guard let frameView = contentView?.superview, let control = Self.segmentedControl(in: frameView) else { return nil }
        let frames = Self.segmentFrames(under: control)
        guard frames.count == stack.tabs.count, !frames.isEmpty else { return nil }
        let x = convertPoint(toScreen: event.locationInWindow).x
        return frames.firstIndex { x < $0.maxX } ?? frames.count - 1
    }

    // MARK: Look

    /// The active app keeps its cursor while a segment is carried, unless this app is allowed to set the cursor
    /// too. If the call is missing nothing changes.
    private static let setsCursorInBackground: Void = {
        let connection = CGSMainConnectionID()
        CGSSetConnectionProperty(connection, connection, "SetsCursorInBackground" as CFString, kCFBooleanTrue)
    }()

    /// The toolbar control dims while its window is not the active one, and this panel never is: it must not take
    /// the focus from the app being used. Answering the window's own "do I look active" question with yes keeps the
    /// control bright without activating anything. It is an AppKit private selector, so it is replaced on this class
    /// only; if a system update drops it, the pill merely goes back to the dimmed look.
    private static let looksActive: Void = {
        let yes: @convention(block) (AnyObject) -> Bool = { _ in true }
        class_replaceMethod(PillPanel.self, NSSelectorFromString("_hasActiveAppearance"),
                            imp_implementationWithBlock(yes), "B@:")
    }()

    /// The system control gives every segment the width of the longest name, so one long window name pushes the
    /// others' icons far from their names. For the control of this panel only, segments are as wide as their own
    /// text. Private AppKit class and selectors: when one is missing nothing changes and widths stay equal.
    private static let fitsSegments: Void = {
        guard let cls = NSClassFromString("NSToolbarItemGroupPickerExpandedView") else { return }
        typealias SizeGetter = @convention(c) (AnyObject, Selector) -> NSSize
        typealias IntGetter = @convention(c) (AnyObject, Selector) -> Int
        for name in ["intrinsicContentSize", "fittingSize"] {
            let sel = NSSelectorFromString(name)
            guard let original = class_getMethodImplementation(cls, sel) else { continue }
            let block: @convention(block) (NSSegmentedControl) -> NSSize = { control in
                guard control.window is PillPanel else { return unsafeBitCast(original, to: SizeGetter.self)(control, sel) }
                guard let panel = control.window as? PillPanel else { return .zero }
                let font = NSFont.systemFont(ofSize: 13)
                let widths = (0..<control.segmentCount).map {
                    IconFont.width(of: control.label(forSegment: $0) ?? "", font: font) + segmentPadding
                }
                panel.estimatedWidth = widths.reduce(0, +)
                return NSSize(width: panel.estimatedWidth + panel.widthCorrection, height: 36)
            }
            class_replaceMethod(cls, sel, imp_implementationWithBlock(block), "{CGSize=dd}@:")
        }
        let distribution = NSSelectorFromString("segmentDistribution")
        if let original = class_getMethodImplementation(cls, distribution) {
            let block: @convention(block) (NSSegmentedControl) -> Int = { control in
                control.window is PillPanel
                    ? NSSegmentedControl.Distribution.fit.rawValue
                    : unsafeBitCast(original, to: IntGetter.self)(control, distribution)
            }
            class_replaceMethod(cls, distribution, imp_implementationWithBlock(block), "q@:")
        }
    }()

    /// Room kept around the segments so the toolbar never has to collapse the group into an overflow menu.
    static let margin: CGFloat = 40

    /// The width the panel needs: its segments (measured like the control does) and the room around them. Measuring
    /// text is not free and this is asked several times a second, so it is redone only when the labels changed.
    var barWidth: CGFloat {
        let key = currentKey() + String(describing: widthCorrection)
        if let measured, measured.key == key { return measured.width }
        let font = NSFont.systemFont(ofSize: 13)
        let width = titles().map { IconFont.width(of: $0, font: font) + Self.segmentPadding }.reduce(0, +) + widthCorrection + 2 * Self.margin
        measured = (key, width)
        return width
    }

    func fade(to shown: Bool) {
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.15
            animator().alphaValue = shown ? 1 : 0
        }
    }

    // MARK: Content

    /// Rebuilds the segments when the windows, their names or the chosen look changed and follows the active window.
    func refresh() {
        iconFont.syncBrands()
        let content = settings.values.pillContent
        let key = currentKey()
        // A rebuild would end the press the control is tracking: it waits for the release.
        if key != shownKey && !stack.interacting {
            shownKey = key
            fitPending = true
                // Icons are characters of a font built for them, so the font has to exist before the titles do.
            if content != .name { stack.tabs.forEach { _ = iconCharacter(for: $0) } }
            let bar = NSToolbar(identifier: "paneflip.pill.\(UUID().uuidString)")
            bar.delegate = self
            bar.displayMode = .iconOnly
            // The look comes from the settings only: no customisation sheet, no display-mode menu on right click.
            bar.allowsUserCustomization = false
            bar.autosavesConfiguration = false
            bar.allowsDisplayModeCustomization = false
            toolbar = bar
            DispatchQueue.main.async { [weak self] in self?.applyIconFont() }
        }
        if carriedID == nil, let id = stack.activeID, let index = stack.tabs.firstIndex(where: { $0.id == id }),
           group?.selectedIndex != index {
            group?.selectedIndex = index
        }
        applyIconFont()
        if fitPending { fitWidth() }
    }

    private func iconCharacter(for tab: ZoneStack.Tab) -> Character {
        iconFont.character(for: tab.bundleID.isEmpty ? tab.appName : tab.bundleID, bundleID: tab.bundleID, appName: tab.appName, icon: tab.icon ?? NSWorkspace.shared.icon(for: .applicationBundle))
    }


    /// The control draws icon characters only when its font falls back to the icon font.
    private func applyIconFont() {
        guard settings.values.pillContent != .name, let frameView = contentView?.superview,
              let control = Self.segmentedControl(in: frameView), let name = iconFont.fontName,
              control !== styledControl || name != styledName,
              let font = iconFont.font(basedOn: NSFont.systemFont(ofSize: 13, weight: .medium)) else { return }
        control.font = font
        styledControl = control
        styledName = name
    }

    /// The estimate in `fitsSegments` is close, not exact: segments get whole-point widths. Once laid out, the
    /// control's real segment widths are read (from its accessibility children) and the estimate is corrected so
    /// the pill is exactly as wide as its segments, which leaves the same space at both ends. The next refresh
    /// rebuilds the toolbar with the corrected estimate; a correction that does not change ends the rebuilding.
    private func fitWidth() {
        guard let frameView = contentView?.superview, let control = Self.segmentedControl(in: frameView) else { return }
        let segments = Self.segmentFrames(under: control)
        guard segments.count == stack.tabs.count, estimatedWidth > 0 else { return }
        fitPending = false
        let wanted = segments.map(\.width).reduce(0, +) + Self.slack
        let correction = wanted - estimatedWidth
        guard abs(correction - widthCorrection) >= 0.5 else { return }
        // The toolbar only measures its item when it is built: rebuild once with the corrected estimate.
        widthCorrection = correction
        shownKey = ""
    }

    /// Space added to the segments' total width, measured so the selected thumb sits as far from the ends of the
    /// pill as from its top and bottom (6 px each, for names, icons and both).
    private static let slack: CGFloat = 2

    private static func segmentFrames(under control: NSView) -> [NSRect] {
        func walk(_ element: Any) -> [NSRect] {
            guard let object = element as? NSObject else { return [] }
            if object.value(forKey: "accessibilityRole") as? String == NSAccessibility.Role.radioButton.rawValue,
               let frame = object.value(forKey: "accessibilityFrame") as? NSValue { return [frame.rectValue] }
            return ((object.value(forKey: "accessibilityChildren") as? [Any]) ?? []).flatMap(walk)
        }
        return walk(control).sorted { $0.minX < $1.minX }
    }

    private static func segmentedControl(in view: NSView) -> NSSegmentedControl? {
        if let control = view as? NSSegmentedControl { return control }
        for sub in view.subviews { if let found = segmentedControl(in: sub) { return found } }
        return nil
    }

    @objc private func chosen(_ sender: NSToolbarItemGroup) {
        guard stack.tabs.indices.contains(sender.selectedIndex) else { return }
        // Carrying: the order was already followed live while dragging. The control's own selection (the segment
        // under the pointer when released) says nothing about it and must not change the order again.
        guard carriedID == nil else { return }
        select(stack.tabs[sender.selectedIndex].id)
    }

    private func currentKey() -> String {
        settings.values.pillContent.rawValue + String(iconFont.revision) + stack.tabs.map { "\($0.id)\u{1F}\($0.displayName)" }.joined(separator: "\u{1E}")
    }

    private func titles() -> [String] {
        switch settings.values.pillContent {
        case .name: stack.tabs.map(shownName)
        case .icon: stack.tabs.map { String(iconCharacter(for: $0)) }
        case .both: stack.tabs.map { "\(iconCharacter(for: $0)) \(shownName($0))" }
        }
    }

    /// No segment is wider than this; a longer name is cut and ends in an ellipsis.
    private static let maxSegmentWidth: CGFloat = 240

    private func shownName(_ tab: ZoneStack.Tab) -> String {
        let font = NSFont.systemFont(ofSize: 13)
        // The icon and its space come first, then the control's own padding.
        let icon = settings.values.pillContent == .both ? IconFont.width(of: "\u{E000} ", font: font) : 0
        return IconFont.fitting(tab.displayName, in: Self.maxSegmentWidth - Self.segmentPadding - icon, font: font)
    }

    // MARK: NSToolbarDelegate

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] { [.flexibleSpace, groupID, .flexibleSpace] }
    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] { [.flexibleSpace, groupID] }

    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier identifier: NSToolbarItem.Identifier,
                 willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        guard identifier == groupID, !stack.tabs.isEmpty else { return nil }
        let names = stack.tabs.map(\.displayName)
        let item = NSToolbarItemGroup(itemIdentifier: identifier, titles: titles(), selectionMode: .selectOne, labels: names,
                                      target: self, action: #selector(chosen))
        group = item
        item.selectedIndex = stack.tabs.firstIndex { $0.id == stack.activeID } ?? 0
        return item
    }
}
