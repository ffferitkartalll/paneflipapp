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
    /// The fingers lead the grid (`ZoneWindowsLeading`): where the pictures were when they took hold (`from`, as `ZoneWindowsModel.appear`), whether the grid was on its way to
    /// open then (`heading`: where it goes if the fingers lift having done little), how far up they have gone since, in points, and whether they have lifted. While it opens
    /// the pictures follow the fingers only once the real windows are away (`leadReady`).
    private var lead: (from: CGFloat, heading: Bool, travel: CGFloat, lifted: Bool)?
    private var leadReady = false
    /// Until when the pictures catch up with fingers that went on before the pictures could move (`ready`), and how long that takes.
    private var leadCatchUp: Date?
    private static let catchUp: TimeInterval = 0.2
    /// The way the fingers went toward where the grid is heading, with its speed: a fast flick that way goes on as far as a long swipe does, as between the windows of a zone.
    private var leadScrub = ScrubGesture()
    /// The slides in progress, each with how far it takes the pictures and since when: a slide begun in the middle of another does not replace it, the two add up (as the
    /// system runs them). Where the pictures are now is read from them (`appearNow`), so that whatever comes in the middle (the fingers, the shortcut, a click) goes on from there.
    private var glides: [(delta: CGFloat, start: Date)] = []
    /// Counts the times the grid began to close: the end of a closing slide that was taken back does nothing.
    private var closeRun = 0
    /// The pictures are back over their places and the real windows are coming back: from here the grid closes to its end, and one asked for meanwhile opens after it.
    private var restoring = false
    private var reopen: UUID?
    /// The part of the way from which the grid goes on by itself when the fingers lift (a fast flick goes on from anywhere): the share of a zone's width from which a swipe goes on to the next window.
    private static let leadCommit = ScrubGesture.dragShare

    /// How far the fingers go to open or close the grid, in points: the height of the zone, as a swipe to the side goes its width for one window.
    private func leadDistance(of model: ZoneWindowsModel) -> CGFloat { max(model.size.height, 100) }
    /// Mission Control goes both ways with one motion: a quick start and a long, soft landing, the same time in and out (the system gives no value for it; this is the look of it).
    private static let curve = UnitCurve.bezier(startControlPoint: UnitPoint(x: 0.3, y: 0), endControlPoint: UnitPoint(x: 0.15, y: 1))
    private static let slideTime: TimeInterval = 0.38
    private static let slide = Animation.timingCurve(curve, duration: slideTime)
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
        if phase == .closing { return comeBack(to: zone) }
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

    /// The shortcut and the wheel button: they open the grid of `zone`, close the one that is open or opening, and open again the one that is closing, each from where
    /// the pictures are.
    func toggle(zone: UUID?) {
        switch phase {
        case nil: if let zone { show(zone: zone) }
        case .closing: if let shown = self.zone { comeBack(to: shown) }
        case .opening, .open: hide()
        }
    }

    /// The grid that is closing opens again from where its pictures are; once the real windows are on their way back it closes first (asked twice: it stays closed).
    private func comeBack(to zone: UUID) {
        guard !restoring, self.zone == zone, model != nil else { return reopen = reopen == nil ? zone : nil }
        closeRun += 1
        goOpen()
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
        guard let current = lead else { return goOpen() }
        leadReady = true
        // The fingers went on while the windows were taken away: the pictures do not start where the fingers are, they catch up with them (or, the fingers up, go the whole way).
        guard !current.lifted else { return finishLead() }
        leadCatchUp = Date().addingTimeInterval(Self.catchUp)
        setAppear(leadValue(of: current, in: model), of: model)
    }

    /// The pictures slide to their places from where they are, and the grid is the keys' and the mouse's.
    private func goOpen() {
        guard phase != nil, let model else { return }
        phase = .open
        panel?.makeKey()   // the keys are the grid's now
        slide(model, to: 1)
        if timer == nil { timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in self?.refresh() } }
        if monitors.isEmpty { watch() }
    }

    /// Where the pictures are now: where they are going, less what each slide in progress has still to do.
    private func appearNow(_ model: ZoneWindowsModel) -> CGFloat {
        let now = Date()
        glides.removeAll { now.timeIntervalSince($0.start) >= Self.slideTime }
        return glides.reduce(model.appear) { $0 - $1.delta * (1 - Self.curve.value(at: now.timeIntervalSince($1.start) / Self.slideTime)) }
    }

    private func slide(_ model: ZoneWindowsModel, to value: CGFloat, then: @escaping () -> Void = {}) {
        glides.append((value - model.appear, Date()))
        withAnimation(Self.slide, completionCriteria: .removed) { model.appear = value } completion: { then() }
    }

    // MARK: Led by the fingers

    /// The zone under the pointer, if it has the focus: the one whose grid the fingers and the wheel button open and close.
    var pointedZone: UUID? { coordinator.zoneID(at: screens.pointerAX).flatMap { $0 == coordinator.focusedZoneID ? $0 : nil } }

    /// The fingers take hold of the grid wherever it is: shut (up opens it), open (down closes it), and in the middle of opening or closing, from where the pictures are.
    func moveLead(by up: CGFloat, at time: TimeInterval) {
        // The first move of a swipe is the whole way the fingers went while its direction was decided, in one piece: the pictures do not jump that far, they go from where they are.
        let up = lead == nil ? up.sign == .minus ? -CGFloat.leastNonzeroMagnitude : .leastNonzeroMagnitude : up
        if lead == nil {
            leadScrub = ScrubGesture()
            switch phase {
            case nil:
                guard up > 0, let zone = pointedZone else { return }
                lead = (0, false, 0, false)
                show(zone: zone)
                if phase == nil { lead = nil }   // nothing to show
            case .opening: lead = (0, true, 0, false)   // opened another way, the windows still going: the pictures are the fingers' once they can move
            case .open:
                guard let model else { return }
                let now = appearNow(model)
                guard up < 0 || now < 1 else { return }   // open and at rest: only a swipe down takes hold
                hold(model)
                lead = (now, true, 0, false)
            case .closing:
                guard !restoring, let model else { return }
                let now = appearNow(model)
                hold(model)
                closeRun += 1
                phase = .open
                lead = (now, false, 0, false)
            }
        }
        guard var current = lead, let model else { return }
        leadScrub.add(up, at: time)
        let distance = leadDistance(of: model)
        current.travel = min(max(current.travel + up, -current.from * distance), (1 - current.from) * distance)
        lead = current
        if phase == .open || leadReady { setAppear(leadValue(of: current, in: model), of: model) }
    }

    private func leadValue(of lead: (from: CGFloat, heading: Bool, travel: CGFloat, lifted: Bool), in model: ZoneWindowsModel) -> CGFloat {
        min(max(lead.from + lead.travel / leadDistance(of: model), 0), 1)
    }

    func endLead() {
        guard var current = lead else { return }
        current.lifted = true
        lead = current
        if phase == .open || leadReady {
            finishLead()
        } else if !current.heading, current.travel < Self.leadCommit * 100, !(leadScrub.isFlick && leadScrub.speed > 0) {
            reset()   // the pictures never came: nothing to take back
        }
    }

    /// The fingers lifted: the grid goes the way a fast flick sent it; or the way they took it, if that was far enough; or on to where it was going.
    private func finishLead() {
        guard let current = lead, let model, phase == .open || phase == .opening else { return lead = nil }
        lead = nil
        leadReady = false
        leadCatchUp = nil
        let moved = current.travel / leadDistance(of: model)
        let opens = leadScrub.isFlick ? leadScrub.speed > 0 : abs(moved) >= Self.leadCommit ? moved > 0 : current.heading
        if opens { goOpen() } else { hide() }
    }

    /// The pictures go with the fingers. The trackpad tells of them less often, and less evenly, than the display draws: each step is glided to in a moment (with no swing
    /// past it), so the pictures move at every frame and not by jumps.
    private static let follow = Animation.interactiveSpring(response: 0.1, dampingFraction: 1)

    private func setAppear(_ value: CGFloat, of model: ZoneWindowsModel) {
        // While they catch up the pictures glide to where the fingers are, in the time that is left of it: at its end they are with the fingers, and stay with them.
        if let left = leadCatchUp?.timeIntervalSinceNow, left > 0.01 { return withAnimation(.easeOut(duration: left)) { model.appear = value } }
        leadCatchUp = nil
        withAnimation(Self.follow) { model.appear = value }
    }

    /// The pictures stop where they are, in the middle of a slide: the fingers have them from there.
    private func hold(_ model: ZoneWindowsModel) {
        let now = appearNow(model)
        glides = []
        var still = Transaction()
        still.disablesAnimations = true
        withTransaction(still) { model.appear = now }
    }

    // MARK: Closing

    /// The pictures slide back over their windows (the chosen one, if any, on top), the windows come back, and the grid fades away.
    func hide(choosing card: IslandWindow? = nil) {
        if phase == .opening {
            guard model != nil else { return reset() }   // its pictures have not come yet
            phase = .open
        }
        guard phase == .open, let model else { return }
        phase = .closing
        lead = nil
        leadReady = false
        leadCatchUp = nil
        stopWatching()
        timer?.invalidate()
        timer = nil
        if let card { model.front = card.id }
        closeRun += 1
        let run = closeRun
        slide(model, to: 0) { [weak self] in
            guard let self, run == closeRun else { return }   // taken back meanwhile
            restore(choosing: card)
        }
    }

    private func restore(choosing card: IslandWindow?) {
        guard phase == .closing, let zone, let stack = coordinator.stacks[zone] else { return reset() }
        restoring = true
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
        leadCatchUp = nil
        glides = []
        restoring = false
        if let again = reopen {
            reopen = nil
            show(zone: again)
        }
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
