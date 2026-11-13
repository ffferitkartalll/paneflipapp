import AppKit
import PaneFlipCore
import SwiftUI

/// The windows of one zone as a grid of pictures laid over the zone (`ZoneWindowsView`), opened by the button at the left end of the zone's notch: every slot of the zone,
/// also the apps that are not open, in the order of the zone, as many by as many as the grid needs (`ZoneGrid`).
///
/// It opens in order: the pictures of the windows are taken first; the grid then begins with each picture exactly over its window, so that nothing is seen to change when
/// the real windows go to wait at the display's edge (as they do while the layout scrolls); only then do the pictures slide into their places. It closes the other way: the
/// pictures slide back over the places of the windows, the windows come back, and the grid fades away over them. A click on a card brings that window to the front of its
/// zone and closes the grid; a card can be carried to another place; Escape, a click on the dimmed zone or outside it closes it.
final class ZoneWindowsOverlay: ZonePresenting, ZoneWindowsLeading {
    private let coordinator: StackCoordinator
    private let screens: ScreenProviding
    private let source: ZoneCardSource
    private let snapshots: WindowSnapshotting
    private let planner: ZonePlanner
    private let mover: WindowMover
    private weak var refresher: ZoneRefreshing?
    /// The room between the zones of a screen's layout: between the cards too.
    private let gapOf: (ScreenInfo) -> CGFloat

    private enum Phase { case opening, open, closing }
    private var phase: Phase?
    private var panel: NSPanel?
    private var model: ZoneWindowsModel?
    private var zone: UUID?
    private var timer: Timer?
    private var monitors: [Any] = []
    /// The windows pictures were asked for already.
    private var asked: Set<CGWindowID> = []
    /// The real windows of the zone while they wait at the display's edge, and whether the grid holds the zones (`StackCoordinator.isScrolling`) meanwhile.
    private var parked: [WindowRef] = []
    private var holding = false
    /// The app whose card was clicked and that is not open yet: the grid stays until its window is in the zone, then that window is chosen.
    private var opening: (bundleID: String, since: Date, shownAt: Date?)?
    /// The fingers lead the grid (`ZoneWindowsLeading`): how far they have gone toward where it is heading, in points, and whether the fingers have lifted. While it opens the pictures
    /// follow the fingers only once the real windows are away (`leadReady`).
    private var lead: (closing: Bool, travel: CGFloat, lifted: Bool)?
    private var leadReady = false
    /// The part of the way from which the grid goes on by itself when the fingers lift.
    private static let leadCommit: CGFloat = 0.35

    /// The way of the card that goes farthest between its window and its place, in points: the fingers go as far as that card, so it follows them as the pictures of the windows do.
    private func leadDistance(of model: ZoneWindowsModel) -> CGFloat {
        let middle = CGPoint(x: model.size.width / 2, y: model.size.height / 2)
        let cells = model.cells
        let ways = model.cards.enumerated().compactMap { index, card -> CGFloat? in
            guard cells.indices.contains(index) else { return nil }
            let from = model.origins[card.id].map { CGPoint(x: $0.midX, y: $0.midY) } ?? middle
            return hypot(cells[index].midX - from.x, cells[index].midY - from.y)
        }
        return max(ways.max() ?? 0, 100)
    }
    /// Mission Control goes both ways with one motion: a quick start and a long, soft landing, the same time in and out (the system gives no value for it; this is the look of it).
    private static let slide = Animation.timingCurve(0.3, 0, 0.15, 1, duration: 0.38)
    private static let reorder = Animation.smooth(duration: 0.25)
    /// An app that does not answer in time does not hold the grid back for good.
    private static let waitForWindows: TimeInterval = 0.3

    init(coordinator: StackCoordinator, screens: ScreenProviding, source: ZoneCardSource, snapshots: WindowSnapshotting, planner: ZonePlanner, mover: WindowMover,
         refresher: ZoneRefreshing, gapOf: @escaping (ScreenInfo) -> CGFloat) {
        self.coordinator = coordinator
        self.screens = screens
        self.source = source
        self.snapshots = snapshots
        self.planner = planner
        self.mover = mover
        self.refresher = refresher
        self.gapOf = gapOf
    }

    var isShown: Bool { phase != nil }

    // MARK: Opening

    func show(zone: UUID) {
        guard phase == nil, !coordinator.isMoving, let stack = coordinator.stacks[zone] else { return }
        let cards = source.allCards(of: zone)
        guard !cards.isEmpty else { return }
        phase = .opening
        self.zone = zone
        snapshots.prepare()
        let refs = cards.compactMap { $0.windowID.flatMap { stack.refs[$0] } }
        asked = Set(refs.map(\.id))
        snapshots.snapshots(of: refs) { [weak self] pictures in self?.begin(zone: zone, cards: cards, pictures: pictures) }
    }

    /// The pictures are here: the grid is put over the zone with each picture over its window.
    /// The panel is larger than the zone by the room the shadows of the cards at its edge need: they are not cut at the zone's edge.
    private static func panelFrame(for zone: CGRect) -> CGRect { zone.insetBy(dx: -ZoneWindowsModel.shadowRoom, dy: -ZoneWindowsModel.shadowRoom) }

    private func begin(zone: UUID, cards: [IslandWindow], pictures: [CGWindowID: WindowPicture]) {
        guard phase == .opening, self.zone == zone, let stack = coordinator.stacks[zone] else { return reset() }
        let frame = screens.flip(stack.rect)
        let all = screens.screens()
        let screen = all.first { $0.cocoaFrame.contains(CGPoint(x: frame.midX, y: frame.midY)) }
        let model = ZoneWindowsModel()
        model.cards = cards
        model.size = frame.size
        model.gap = screen.map(gapOf) ?? 0
        model.front = cards.first(where: \.isActive)?.id
        model.highlighted = model.front ?? cards.first?.id
        for (id, picture) in pictures {
            model.pictures["w\(id)"] = picture
            model.origins["w\(id)"] = CGRect(x: picture.frame.minX - stack.rect.minX, y: picture.frame.minY - stack.rect.minY, width: picture.frame.width, height: picture.frame.height)
        }
        model.onChoose = { [weak self] card in self?.choose(card) }
        model.onPerform = { [weak self] action, card in self?.perform(action, on: card) }
        model.onToggleStart = { [weak self] card in self?.toggleStart(card) }
        model.onMove = { [weak self] card, target in self?.move(card, to: target) }
        model.onClose = { [weak self] in self?.hide() }
        let panel = ZoneWindowsPanel(contentRect: Self.panelFrame(for: frame), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.level = .statusBar   // above the Dock and the menu bar, which would cut the shadows of the cards at the zone's edge (the panel is larger than the zone)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.animationBehavior = .none
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary]
        let host = ZoneWindowsHostingView(rootView: ZoneWindowsView(model: model))
        host.sizingOptions = []
        panel.contentView = host
        panel.setFrame(Self.panelFrame(for: frame), display: true)
        panel.orderFrontRegardless()
        self.panel = panel
        self.model = model
        coordinator.switchLocked = true   // from now on only a click on a card switches the windows of the zone
        // The windows go only if the picture of the one in front is there to stand in for it, and there is a side of the display with nothing beyond it to wait at.
        let side = screen.flatMap { planner.strip(of: $0, among: all)?.1 }
        let front = cards.first(where: \.isActive)?.windowID
        // A few frames for the window server to put the pictures on screen, then the real windows may go.
        DispatchQueue.main.asyncAfter(deadline: .now() + PanelSlideStage.settle) { [weak self] in
            guard let self, phase == .opening, self.model === model else { return }
            guard let screen, let side, let front, pictures[front] != nil else { return ready() }
            park(stack, on: screen, side: side) { [weak self] in self?.ready() }
        }
    }

    /// The real windows wait at the display's edge, as they do while the layout scrolls; `then` runs once they have gone.
    private func park(_ stack: ZoneStack, on screen: ScreenInfo, side: Parking.Side, then: @escaping () -> Void) {
        parked = Array(stack.refs.values)
        coordinator.isScrolling = true
        holding = true
        let waiting = Parking.frame(for: stack.rect, on: screen.cocoaFrame, side: side).origin
        parked.forEach { mover.move($0, to: waiting) }
        wait { [weak self] in
            self?.refresher?.refreshZones()   // the notches (and the island) give way: nothing but the cards is in sight
            then()
        }
    }

    /// Runs `then` once the windows asked to move have moved, or after a moment if one does not answer.
    private func wait(then: @escaping () -> Void) {
        var done = false
        let finish = { guard !done else { return }; done = true; then() }
        mover.flush(then: finish)
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.waitForWindows, execute: finish)
    }

    /// The pictures are over the windows and the windows are away (or cannot be): the grid opens, or, led by the fingers, follows them from here.
    private func ready() {
        guard phase == .opening, let model else { return }
        guard let current = lead else { return open() }
        leadReady = true
        setAppear(min(current.travel / leadDistance(of: model), 1), of: model)
        if current.lifted { finishLead() }
    }

    private func open() {
        guard phase == .opening, let model else { return }
        phase = .open
        panel?.makeKey()   // the keys are the grid's now
        withAnimation(Self.slide) { model.appear = 1 }
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in self?.refresh() }
        watch()
    }

    // MARK: Led by the fingers

    /// The zone under the pointer, if it has the focus: the one whose grid the fingers and the wheel button open and close.
    var pointedZone: UUID? { coordinator.zoneID(at: screens.pointerAX).flatMap { $0 == coordinator.focusedZoneID ? $0 : nil } }

    func moveLead(by up: CGFloat) {
        if lead == nil {
            if phase == nil, up > 0, let zone = pointedZone {
                lead = (false, 0, false)
                show(zone: zone)
                if phase == nil { lead = nil }   // nothing to show
            } else if phase == .open, up < 0 {
                lead = (true, 0, false)
            }
        }
        guard var current = lead, let model else { return }
        current.travel = max(current.travel + (current.closing ? -up : up), 0)
        if leadReady || phase == .open { current.travel = min(current.travel, leadDistance(of: model)) }
        lead = current
        if current.closing ? phase == .open : leadReady {
            let done = current.travel / leadDistance(of: model)
            setAppear(current.closing ? 1 - done : done, of: model)
        }
    }

    func endLead() {
        guard var current = lead else { return }
        current.lifted = true
        lead = current
        if current.closing || leadReady { finishLead() } else if current.travel < Self.leadCommit * 100 { reset() }   // the pictures never came: nothing to take back
    }

    /// The fingers lifted: the grid goes on to open or close if they took it far enough, or goes back to where it was.
    private func finishLead() {
        guard let current = lead, let model, phase == .open || phase == .opening else { return lead = nil }
        lead = nil
        leadReady = false
        let goes = current.travel >= Self.leadCommit * leadDistance(of: model)
        switch (current.closing, goes) {
        case (true, true): hide()
        case (true, false): withAnimation(Self.slide) { model.appear = 1 }
        case (false, true): open()
        case (false, false):
            phase = .open
            hide()
        }
    }

    /// The pictures take their place at once, with the fingers.
    private func setAppear(_ value: CGFloat, of model: ZoneWindowsModel) {
        var still = Transaction()
        still.disablesAnimations = true
        withTransaction(still) { model.appear = value }
    }

    // MARK: Closing

    /// The pictures slide back over their windows (the chosen one, if any, on top), the windows come back, and the grid fades away.
    func hide(choosing card: IslandWindow? = nil) {
        guard phase == .open, let model else { return }
        phase = .closing
        lead = nil
        stopWatching()
        timer?.invalidate()
        timer = nil
        if let card { model.front = card.id }
        withAnimation(Self.slide, completionCriteria: .removed) { model.appear = 0 } completion: { [weak self] in self?.restore(choosing: card) }
    }

    private func restore(choosing card: IslandWindow?) {
        guard phase == .closing, let zone, let stack = coordinator.stacks[zone] else { return reset() }
        parked.forEach { mover.move($0, to: stack.frame.origin) }
        let done = { [weak self] in
            guard let self, phase == .closing else { return }
            release()
            if let card { activate(card, in: zone, stack: stack) }
            // The real windows stand where they were: the grid fades away over them.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) { [weak self] in self?.fadeOut() }
        }
        if parked.isEmpty { done() } else { wait(then: done) }
    }

    /// The window of the card chosen is put in front, as it stands (no slide: its picture has grown to be the window); the card of an app that is not open opens it.
    private func activate(_ card: IslandWindow, in zone: UUID, stack: ZoneStack) {
        guard let id = card.windowID else { return source.choose(card, in: zone) }
        if !card.isActive { coordinator.select(id, in: stack) }
        coordinator.focus(zone: zone)
    }

    /// The windows are back: the zones are free again.
    private func release() {
        parked = []
        coordinator.switchLocked = false
        if holding {
            holding = false
            coordinator.isScrolling = false
            refresher?.refreshZones()
        }
    }

    private func fadeOut() {
        guard let panel, phase == .closing else { return reset() }
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.12
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in self?.reset() })
    }

    /// Everything goes back as it was, at once: the windows too (the zone is gone, or the grid is torn down).
    private func reset() {
        stopWatching()
        timer?.invalidate()
        timer = nil
        if !parked.isEmpty, let zone, let stack = coordinator.stacks[zone] {
            parked.forEach { mover.move($0, to: stack.frame.origin) }
            mover.flush {}
        }
        release()
        panel?.orderOut(nil)
        panel = nil
        model = nil
        zone = nil
        phase = nil
        asked = []
        opening = nil
        lead = nil
        leadReady = false
    }

    func zonesDidChange() {
        guard let zone, let model, let panel else { return }
        guard let stack = coordinator.stacks[zone] else { return reset() }   // the zone is gone, or the app is switched off
        let frame = screens.flip(stack.rect)
        if panel.frame != Self.panelFrame(for: frame) { panel.setFrame(Self.panelFrame(for: frame), display: true); model.size = frame.size }
    }

    // MARK: Cards

    /// A window's card closes the grid on that window. The card of an app that is not open opens the app and the grid stays: it closes on the window once it has come into the zone
    /// and its picture is here (so that the picture can grow to be the window), or stays open if the app does not come within a while.
    private func choose(_ card: IslandWindow) {
        guard card.windowID == nil, let zone else { return hide(choosing: card) }
        guard opening == nil else { return }
        opening = (card.bundleID, Date(), nil)
        source.choose(card, in: zone)
        waitForOpening()
    }

    private func waitForOpening() {
        guard phase == .open, let model, let current = opening else { return }
        refresh()
        if let card = model.cards.first(where: { $0.bundleID == current.bundleID && $0.windowID != nil }) {
            let shownAt = current.shownAt ?? Date()
            opening?.shownAt = shownAt
            if model.pictures[card.id] != nil || Date().timeIntervalSince(shownAt) > 1.5 {
                opening = nil
                model.origins[card.id] = CGRect(origin: .zero, size: model.size)   // it stands as the zone's front window: the card grows to fill the zone
                return hide(choosing: card)
            }
        } else if Date().timeIntervalSince(current.since) > 15 {
            opening = nil
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in self?.waitForOpening() }
    }

    private func perform(_ action: IslandCardAction, on card: IslandWindow) {
        guard phase == .open, let zone else { return }
        source.perform(action, on: card, in: zone)
        // The window needs a moment to go (or to be hidden): the cards are read again then.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in self?.refresh() }
    }

    private func toggleStart(_ card: IslandWindow) {
        guard phase == .open, let zone else { return }
        source.toggleStart(card, in: zone)
        refresh()
    }

    /// `card`, carried over the grid, is put in the place of `target`: the zone's windows stand in the new order, and the cards are read again.
    private func move(_ card: IslandWindow, to target: IslandWindow) {
        guard phase == .open, let zone else { return }
        source.move(card, toPlaceOf: target, in: zone)
        refresh(animated: Self.reorder)
    }

    /// The cards as the zone has them now (a window that came, went or was moved); none left: the grid closes.
    private func refresh(animated: Animation? = .smooth(duration: 0.25)) {
        guard phase == .open, let zone, let model, let stack = coordinator.stacks[zone] else { return }
        let now = source.allCards(of: zone)
        guard !now.isEmpty else { return hide() }
        if now != model.cards { withAnimation(animated) { model.cards = now } }
        if !now.contains(where: { $0.id == model.highlighted }) { model.highlighted = now.first(where: \.isActive)?.id ?? now.first?.id }   // its window went
        askForPictures(of: now, in: stack)
    }

    /// The pictures of the windows that have none yet (one that came while the grid was open): they come one by one, the card shows the glyph of its app until then.
    private func askForPictures(of cards: [IslandWindow], in stack: ZoneStack) {
        let refs = cards.compactMap { card in card.windowID.flatMap { id in asked.contains(id) ? nil : stack.refs[id] } }
        guard !refs.isEmpty else { return }
        refs.forEach { asked.insert($0.id) }
        let model = self.model
        snapshots.snapshots(of: refs) { [weak self] pictures in
            guard let self, let model, self.model === model else { return }
            withAnimation(.easeOut(duration: 0.15)) {
                for (id, picture) in pictures { model.pictures["w\(id)"] = picture }
            }
        }
    }

    // MARK: Watching

    private func watch() {
        let clicks: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        monitors = [
            NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in if event.keyCode == 53 { self?.hide() } },
            // The arrow keys move the mark, Return chooses, Escape closes; any other key is not let through to the window behind.
            NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self, event.window === panel, let model else { return event }
                switch event.keyCode {
                case 53: hide()
                case 36, 76: model.choosePointed()
                case 123: model.movePointer(columns: -1, rows: 0)
                case 124: model.movePointer(columns: 1, rows: 0)
                case 125: model.movePointer(columns: 0, rows: 1)
                case 126: model.movePointer(columns: 0, rows: -1)
                default: break
                }
                return nil
            },
            // A click in another app's window; one in the grid is its own.
            NSEvent.addGlobalMonitorForEvents(matching: clicks) { [weak self] _ in self?.hide() },
        ].compactMap { $0 }
    }

    private func stopWatching() {
        monitors.forEach { NSEvent.removeMonitor($0) }
        monitors = []
    }
}
