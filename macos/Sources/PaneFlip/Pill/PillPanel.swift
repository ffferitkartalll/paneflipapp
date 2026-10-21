import AppKit
import ObjectiveC
import PaneFlipCore

/// The pill of one zone, a floating panel: a toolbar item group, so it is the system's own Liquid Glass segmented
/// control (the one app toolbars use, with its own animations), with the windows of the zone as segments.
/// Click-through until the presenter shows it.
final class PillPanel: NSPanel, NSToolbarDelegate {
    private let stack: ZoneStack
    private let settings: AppSettings
    private let iconFont: IconFont
    private let select: (CGWindowID) -> Void
    private let reorder: () -> Void
    private let hide: () -> Void
    /// What scrolling over the pill does.
    private let scrolling: PillScrolling?
    /// What the system control adds around a segment's text, in points.
    private static let segmentPadding: CGFloat = 22
    private let groupID = NSToolbarItem.Identifier("tabs")
    private let reorderID = NSToolbarItem.Identifier("reorder")
    private let hideID = NSToolbarItem.Identifier("hide")
    /// What the two buttons and the space before them take next to the segments.
    static let buttonsWidth: CGFloat = 104
    private var group: NSToolbarItemGroup?
    private var movePending = false
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
         select: @escaping (CGWindowID) -> Void, reorder: @escaping () -> Void, hide: @escaping () -> Void, scrolling: PillScrolling? = nil) {
        self.stack = stack
        self.settings = settings
        self.iconFont = iconFont
        self.select = select
        self.reorder = reorder
        self.hide = hide
        self.scrolling = scrolling
        _ = Self.looksActive
        _ = Self.fitsSegments
        super.init(contentRect: NSRect(x: 0, y: 0, width: 100, height: PillMetrics.height),
                   styleMask: [.titled, .fullSizeContentView, .nonactivatingPanel], backing: .buffered, defer: false)
        level = .floating
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        hideWindowButtons()
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

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    /// Scrolling over the pill: two fingers lead the windows of the zone (`PillScrolling`), a wheel steps through them.
    private func scrolled(_ event: NSEvent) {
        guard event.momentumPhase.isEmpty else { return }   // the glide after the fingers lifted is not a new swipe
        if event.hasPreciseScrollingDeltas {
            scrolling?.trackpad(over: stack, horizontal: event.scrollingDeltaX, vertical: event.scrollingDeltaY,
                                began: event.phase.contains(.began) || event.phase.contains(.mayBegin),
                                finished: event.phase.contains(.ended) || event.phase.contains(.cancelled), at: event.timestamp)
        } else {
            scrolling?.wheel(over: stack, delta: abs(event.scrollingDeltaY) >= abs(event.scrollingDeltaX) ? event.scrollingDeltaY : event.scrollingDeltaX)
        }
    }

    /// Only the left button is used. The right button does nothing (not even the toolbar's own context menu).
    override func sendEvent(_ event: NSEvent) {
        switch event.type {
        case .scrollWheel:
            scrolled(event)
            return
        case .rightMouseDown, .rightMouseDragged, .rightMouseUp:
            return
        case .leftMouseDown:
            stack.interacting = true
        case .leftMouseUp:
            super.sendEvent(event)
            stack.interacting = false
            return
        default: break
        }
        super.sendEvent(event)
    }

    // MARK: Look

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
        let width = titles().map { IconFont.width(of: $0, font: font) + Self.segmentPadding }.reduce(0, +) + widthCorrection + Self.buttonsWidth + 2 * Self.margin
        measured = (key, width)
        return width
    }

    /// Hides the window's own buttons; returns whether any of them had been shown.
    @discardableResult
    private func hideWindowButtons() -> Bool {
        var wereShown = false
        for type in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
            guard let button = standardWindowButton(type), !button.isHidden else { continue }
            button.isHidden = true
            wereShown = true
        }
        return wereShown
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
        // A broken pill is recognised by its window's own buttons being shown again: the toolbar keeps room for them
        // and folds its group into a pop-up. They are hidden again and the toolbar is built anew.
        if hideWindowButtons() { shownKey = "" }
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
            // The look comes from the settings only: no customisation sheet, no display-mode menu.
            bar.allowsUserCustomization = false
            bar.autosavesConfiguration = false
            bar.allowsDisplayModeCustomization = false
            toolbar = bar
            DispatchQueue.main.async { [weak self] in self?.applyIconFont() }
        }
        if let id = stack.activeID, let index = stack.tabs.firstIndex(where: { $0.id == id }),
           group?.selectedIndex != index {
            moveSelection(to: index)
        }
        applyIconFont()
        if fitPending { fitWidth() }
        healCollapse()
    }

    /// The thumb glides to the new segment. A press on the control animates itself; a change from elsewhere (the
    /// keyboard) does so only while the pill is on screen, so a pill that is still fading in shows the old
    /// selection first and moves it once it is there. Moved unseen it would look like a jump.
    private func moveSelection(to index: Int) {
        guard alphaValue > 0.9 else {
            guard !movePending else { return }
            movePending = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.17) { [weak self] in
                self?.movePending = false
                self?.refresh()
            }
            return
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.25
            context.allowsImplicitAnimation = true
            group?.selectedIndex = index
        }
    }

    /// The other sign of a broken pill: the group folded into a pop-up, so the segments are gone from the tree. A
    /// toolbar that was just built has none for a moment, so it is seen over a few looks in a row; then the toolbar
    /// is built anew.
    private func healCollapse() {
        guard group != nil, !stack.tabs.isEmpty, !stack.interacting, let frameView = contentView?.superview,
              Self.segmentedControl(in: frameView) == nil else { collapsedLooks = 0; return }
        collapsedLooks += 1
        if collapsedLooks >= 4 {
            collapsedLooks = 0
            shownKey = ""
        }
    }
    private var collapsedLooks = 0

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

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [.flexibleSpace, groupID, .space, reorderID, hideID, .flexibleSpace]
    }
    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [.flexibleSpace, .space, groupID, reorderID, hideID]
    }

    @objc private func reorderPressed() { reorder() }
    @objc private func hidePressed() { hide() }

    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier identifier: NSToolbarItem.Identifier,
                 willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        if identifier == hideID || identifier == reorderID {
            // Buttons of the window toolbar, drawn by the system like the buttons of an app toolbar.
            let hides = identifier == hideID
            let title = hides ? String(localized: "Hide the pill") : String(localized: "Order the apps of the pill")
            let item = NSToolbarItem(itemIdentifier: identifier)
            item.image = NSImage(systemSymbolName: hides ? "eye.slash" : "arrow.left.arrow.right", accessibilityDescription: title)
            item.label = title
            item.toolTip = title
            item.isBordered = true
            item.target = self
            item.action = hides ? #selector(hidePressed) : #selector(reorderPressed)
            return item
        }
        guard identifier == groupID, !stack.tabs.isEmpty else { return nil }
        let names = stack.tabs.map(\.displayName)
        let item = NSToolbarItemGroup(itemIdentifier: identifier, titles: titles(), selectionMode: .selectOne, labels: names,
                                      target: self, action: #selector(chosen))
        group = item
        item.selectedIndex = stack.tabs.firstIndex { $0.id == stack.activeID } ?? 0
        return item
    }
}
