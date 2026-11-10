import AppKit
import PaneFlipCore

/// Pressing the keys of the shortcut (`zoneEdgeEditKeys`) twice quickly turns the mode on (and the same again off; Escape ends it too): the lines between the zones of the screen
/// in view, on the display the pointer is on (the display's own layout or an area beyond its edge, whichever it rests at), show a handle, and a line moves by its handle: the two zones
/// beside the line, and the windows in them, grow and shrink together once the handle is let go (it sticks to a half, a third, a quarter and the like). The layout keeps the new share.
final class DividerResizer: ZonePresenting {
    private struct Line {
        let key: String
        let layoutID: UUID
        let divider: SplitDivider
        /// The screen of the strip the line is in.
        let target: StripGeometry.RestingScreen
        /// The layout of that screen.
        let layer: Layer
    }

    /// The layout of a screen, as the zones are laid out from it.
    private struct Layer {
        let root: LayoutNode
        let area: CGRect
        /// The least a zone may be, in points.
        let least: CGFloat
        /// The zones that keep their width-to-height ratio while a line moves (as in the layout editor), and how the zones of a tree are laid: with the gap, in the margin.
        let aspects: [UUID: ZoneAspect]
        let laid: LayoutNode.Laid
    }

    private let layouts: LayoutManaging
    private let repository: LayoutRepository
    private let planner: ZonePlanner
    private let screens: ScreenProviding
    private let settings: AppSettings
    private let viewport: StripViewport
    private let keys: KeyStateProviding
    private let capsLock: CapsLockKeyState
    private let isBlocked: () -> Bool
    /// The displays as the zones were last laid out (the engine's): asked for every step of a scroll, so not asked of the system.
    private let screensNow: () -> [ScreenInfo]
    /// The display the mode is on (the one the pointer was on when it was turned on), and the screen of its strip the handles were made for.
    private var activeKey: String?
    private var shownRest: StripGeometry.RestingScreen?
    private var handles: [DividerHandle] = []
    /// The handles on show, one for each line (for the tests).
    var shownHandles: [DividerHandle] { handles }
    /// The handle of each line, by the line.
    private var handleByLine: [UUID: DividerHandle] = [:]
    private var monitors: [Any] = []
    /// The line being moved, the ratio it has and the layout of its screen with it there.
    private var dragging: (line: Line, ratio: Double, root: LayoutNode)?
    /// How far from the line's middle the pointer took the handle, along the line's axis.
    private var grabbed: CGFloat = 0
    /// The line being moved sticks to the steps (not at first, when it began on one).
    private var snapping = true
    private static let snapDistance = 12.0
    /// Two presses of the trigger within this long make the mode.
    private static let doublePress: TimeInterval = 0.35
    private static let escape: UInt16 = 53
    /// The key code of the modifier event the Caps Lock key makes.
    private static let capsLockEventCode: UInt16 = 57
    private var active = false
    /// The mode was turned on or off.
    var onChange: ((Bool) -> Void)?
    /// What each move of a line changed, the last on top: the layout and its strip before the move.
    private var history: [(key: String, layoutID: UUID, strip: StripLayout)] = []
    /// There is a move to undo, or there is no longer.
    var onUndoChange: ((Bool) -> Void)?
    private var triggerDown = false
    private var lastPress = Date.distantPast

    init(layouts: LayoutManaging, repository: LayoutRepository, planner: ZonePlanner, screens: ScreenProviding, settings: AppSettings,
         viewport: StripViewport, keys: KeyStateProviding, capsLock: CapsLockKeyState, screensNow: @escaping () -> [ScreenInfo], isBlocked: @escaping () -> Bool) {
        self.screensNow = screensNow
        self.layouts = layouts
        self.repository = repository
        self.planner = planner
        self.screens = screens
        self.settings = settings
        self.viewport = viewport
        self.keys = keys
        self.capsLock = capsLock
        self.isBlocked = isBlocked
    }

    func start() {
        let flags: (NSEvent) -> Void = { [weak self] event in self?.triggerChanged(event) }
        let key: (NSEvent) -> Void = { [weak self] event in if event.keyCode == Self.escape { self?.setActive(false) } }
        monitors = [NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged, handler: flags),
                    NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { event in flags(event); return event },
                    NSEvent.addGlobalMonitorForEvents(matching: .keyDown, handler: key),
                    NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in key(event); return event }].compactMap { $0 }
        // Caps Lock as a modifier key is a key of its own (F18): the event tap that holds it tells when it goes down.
        capsLock.onChange = { [weak self] in self?.triggerChanged(nil) }
    }

    /// The keys of the shortcut went down or up. Without Caps Lock as a modifier key the key is only told by the lock changing (a modifier event of the key
    /// itself), so each such event with the other keys held is one press.
    private func triggerChanged(_ event: NSEvent?) {
        let trigger = settings.values.zoneEdgeEditKeys
        guard !trigger.keys.isEmpty else { return }
        if trigger.keys.contains(where: { $0.code == KeyChord.capsLockKeyCode }) && !settings.values.capsLockAsModifier {
            guard event?.keyCode == Self.capsLockEventCode else { return }
            let others = SnapTrigger(keys: trigger.keys.filter { $0.code != KeyChord.capsLockKeyCode })
            if others.keys.isEmpty || others.isHeld(using: keys) { pressed() }
            return
        }
        let down = trigger.isHeld(using: keys)
        defer { triggerDown = down }
        if down && !triggerDown { pressed() }
    }

    /// One press of the shortcut: a second one soon after the first turns the mode on or off.
    private func pressed() {
        if Date().timeIntervalSince(lastPress) <= Self.doublePress {
            lastPress = .distantPast
            guard settings.values.placementEnabled, !isBlocked() else { return }
            setActive(!active)
        } else {
            lastPress = Date()
        }
    }

    private func setActive(_ on: Bool) {
        guard on != active, dragging == nil else { return }
        active = on
        if on {
            let all = screens.screens(), pointer = screens.pointerAX
            activeKey = (all.first { screens.flip($0.cocoaFrame).contains(pointer) } ?? all.first)?.key
            show()
        } else {
            hide()
            forgetMoves()
            activeKey = nil
        }
        onChange?(on)
    }

    private func forgetMoves() {
        guard !history.isEmpty else { return }
        history = []
        onUndoChange?(false)
    }

    /// Takes back the last move of a line: the layout gets its old strip, the windows glide back, the handles stand where the lines are.
    func undo() {
        guard active, dragging == nil, let last = history.popLast() else { return }
        if repository.layout(id: last.layoutID, key: last.key) != nil { layouts.updateLayout(key: last.key, id: last.layoutID, strip: last.strip, animated: true) }
        remakeHandles()
        onUndoChange?(!history.isEmpty)
    }

    /// Turns the mode on, or off when it is on (the button of the island).
    func toggle() {
        guard settings.values.placementEnabled, !isBlocked() else { return }
        setActive(!active)
    }

    /// Ends the mode.
    func finish() { setActive(false) }

    private func show() {
        let all = screens.screens()
        shownRest = nil
        guard let screen = all.first(where: { $0.key == activeKey }) else { return }
        shownRest = restingScreen(on: screen, among: all)
        for line in lines(on: screen, among: all) {
            let divider = line.divider, place = placement(of: divider)
            let handle = DividerHandle(line: place.line, knob: place.knob, sideBySide: divider.sideBySide, atStep: SplitSnap.isStep(divider.ratio),
                                       onPress: { [weak self] in self?.press(line) }, onDrag: { [weak self] in self?.drag(line) }, onRelease: { [weak self] in self?.release() })
            handles.append(handle)
            handleByLine[divider.id] = handle
        }
        handles.forEach { $0.raiseHandle() }
    }

    /// The layout scrolled to another screen of the strip (or away from them all): the handles are made again for the one in view, none while it is between two.
    func zonesDidChange() {
        guard active, dragging == nil else { return }
        // The desktop was changed or the display is gone: the lines on show belong to a layout that is not in view any more.
        guard let screen = screensNow().first(where: { $0.key == activeKey }) else { return setActive(false) }
        if restingScreen(on: screen, among: screensNow()) != shownRest { remakeHandles() }
    }

    /// The screen of the strip that the display shows, if it rests at one.
    private func restingScreen(on screen: ScreenInfo, among all: [ScreenInfo]) -> StripGeometry.RestingScreen? {
        guard let (geometry, _) = planner.strip(of: screen, among: all) else { return nil }
        return geometry.screen(restingAt: geometry.clamped(viewport.offset(for: screen.key)))
    }

    /// Where the panels of a line stand (Cocoa screen coordinates): the line across its parent, the handle in the middle.
    private func placement(of divider: SplitDivider) -> (line: CGRect, knob: CGPoint) {
        let span = divider.parent, side = DividerKnobView.side
        let line = divider.sideBySide
            ? CGRect(x: divider.position - side / 2, y: span.minY, width: side, height: span.height)
            : CGRect(x: span.minX, y: divider.position - side / 2, width: span.width, height: side)
        let knob = divider.sideBySide ? CGPoint(x: divider.position, y: span.midY) : CGPoint(x: span.midX, y: divider.position)
        return (screens.flip(line), screens.flip(CGRect(origin: knob, size: .zero)).origin)
    }

    private func hide() {
        handles.forEach { $0.close() }
        handles = []
        handleByLine = [:]
    }

    private func lines(on screen: ScreenInfo, among all: [ScreenInfo]) -> [Line] {
        guard let layout = repository.activeLayout(for: screen.key), let (geometry, _) = planner.strip(of: screen, among: all),
              let target = geometry.screen(restingAt: geometry.clamped(viewport.offset(for: screen.key))) else { return [] }
        let root: LayoutNode
        switch target {
        case .own: root = geometry.strip.root
        case .leading(let i): root = geometry.strip.leading[i].root
        case .trailing(let i): root = geometry.strip.trailing[i].root
        }
        // A screen at its rest fills the display, with the margin inside it, as the zones of the plan stand.
        // The lines stand in the area with half a gap more on every side, between the zones that the gap leaves (`LayoutNode.lineArea`).
        let area = LayoutNode.lineArea(geometry.rootArea(margin: CGFloat(layout.edgeMargin(in: settings.values))), gap: CGFloat(layout.gap(in: settings.values)))
        let usable = geometry.rootArea(margin: 0)
        let plain = geometry.rootArea(margin: CGFloat(layout.edgeMargin(in: settings.values))), gap = CGFloat(layout.gap(in: settings.values))
        let layer = Layer(root: root, area: area, least: CGFloat(layout.minZoneSize(in: settings.values)), aspects: layout.zoneAspects,
                          laid: { $0.zones(in: plain, gap: gap) })
        return root.dividers(in: area).map { Line(key: screen.key, layoutID: layout.id, divider: $0.reaching(area, to: usable), target: target, layer: layer) }
    }

    /// Where on the line's axis the pointer is.
    private func axis(of line: Line) -> CGFloat { line.divider.sideBySide ? screens.pointerAX.x : screens.pointerAX.y }

    /// The handle was taken: the line goes with the pointer from where it was taken, not from the line's middle.
    private func press(_ line: Line) {
        grabbed = axis(of: line) - line.divider.position
        // A line that was on a step does not stick to it again at once: it follows the pointer until it has gone a snap distance away.
        snapping = !SplitSnap.isStep(line.divider.ratio)
    }

    private func drag(_ line: Line) {
        let position = axis(of: line) - grabbed
        let free = line.divider.ratio(forPosition: position, snapDistance: 0)
        if abs(free - line.divider.ratio) * Double(line.divider.extent) > Self.snapDistance { snapping = true }
        let wanted = snapping ? line.divider.ratio(forPosition: position, snapDistance: Self.snapDistance) : free
        // No other line moves: the line stops where it would pass the next one.
        guard let moved = line.layer.root.movingLine(line.divider.id, to: wanted, in: line.layer.area, least: line.layer.least, aspects: line.layer.aspects, laid: line.layer.laid) else { return }
        dragging = (line, moved.ratio, moved.node)
        // The lines that meet the moved one grow and shrink with it (their span ends at it).
        for divider in moved.node.dividers(in: line.layer.area) {
            let place = placement(of: divider)
            handleByLine[divider.id]?.update(line: place.line, knob: place.knob, atStep: SplitSnap.isStep(divider.ratio))
        }
    }

    /// The lines stand elsewhere now: the handles are made again from the new layout, the old ones go once the new ones stand, so none disappears.
    private func remakeHandles() {
        let old = handles
        handles = []
        handleByLine = [:]
        if active, !isBlocked() { show() }
        old.forEach { $0.close() }
    }

    private func release() {
        defer {
            let moved = dragging != nil
            dragging = nil
            if moved { remakeHandles() }   // a click that moved nothing leaves the handles as they are
        }
        guard let (line, ratio, root) = dragging, abs(ratio - line.divider.ratio) > 0.002, let layout = repository.layout(id: line.layoutID, key: line.key) else { return }
        var strip = layout.strip
        history.append((line.key, line.layoutID, strip))
        onUndoChange?(true)
        switch line.target {
        case .own: strip.root = root
        case .leading(let i): strip.leading[i].root = root
        case .trailing(let i): strip.trailing[i].root = root
        }
        layouts.updateLayout(key: line.key, id: line.layoutID, strip: strip, animated: true)
    }
}
