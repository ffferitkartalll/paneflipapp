import AppKit
import PaneFlipCore
import SwiftUI

/// The grid of the whole layout (`LayoutGridView`), opened by the "Switch to grid view" button of the open island, the layout grid shortcut, a click of the wheel button or a
/// swipe up with the keys that scroll toward the screens beyond the edges held (or four fingers): on every display with a layout, every zone of it, those of its screens
/// beyond the edges too, each with the grid of its windows. It shows and does what the grid of one zone (`ZoneWindowsOverlay`) shows and does, in every zone of every display
/// at once (the same view and model, the same cards kept by `ZoneCardsKeeper`).
///
/// It opens in order, as the grid of one zone does: the pictures of the windows are taken first; the grid begins with each picture exactly over its window, so that nothing
/// is seen to change when the real windows go to wait at the displays' edge; then the windows of every zone go to their cards. The mouse wheel (and two fingers sideways),
/// over a display, scrolls that display's grid from one screen of its layout to the next. It closes the other way round, at the screens the displays were scrolled to: the
/// layouts stay there. A click on a card brings that window to the front of its zone and closes the grid; a card can be carried to any zone of any display (the zone it would go
/// to is made room in, and a display's grid scrolls to the next screen one screen each time the pointer touches its edge), and goes there when the grid closes; the arrow keys go from card to card, on
/// to the other displays too (a display's grid scrolls to a card out of view), Return chooses, Escape or a click between the zones closes it.
final class LayoutGridOverlay: ZoneCardCarrying, LayoutGridLeading {
    private let coordinator: StackCoordinator
    private let screens: ScreenProviding
    private let source: ZoneCardSource
    private let snapshots: WindowSnapshotting
    private let planner: ZonePlanner
    private let mover: WindowMover
    private weak var refresher: ZoneRefreshing?
    private let gapOf: (ScreenInfo) -> CGFloat
    /// How far the grid goes for the fingers' way: the trackpad speed of the system and of the app's setting, as the layout's own scroll takes it.
    private let gain: () -> CGFloat
    /// Something else holds the screen (the grid of one zone): the grid of the whole layout does not open then.
    var isBlocked: () -> Bool = { false }

    private var phase: LayoutGridPhase?
    private var displays: [LayoutGridDisplay] = []
    private var monitors: [Any] = []
    /// The real windows while they wait at the displays' edge, each with the place it goes back to, and whether the grid holds the zones (`StackCoordinator.isScrolling`).
    private var parked: [(ref: WindowRef, home: CGPoint)] = []
    private var holding = false
    /// The windows were given back and the zones have still to be laid out again.
    private var laysOutLater = false
    private let keeper: ZoneCardsKeeper
    private var timer: Timer?
    /// The app whose card was clicked and that is not open yet: the grid stays until its window is in the zone, then that window is chosen.
    private var opening: (zone: UUID, bundleID: String, since: Date)?
    /// The cards carried to another zone, which go there when the grid closes (until then the grid shows them in their new zone).
    private var moves: [LayoutGridMove] = []
    /// The card the mouse carries, the zone it came from (where it stands now) and the display of it.
    private var carrying: (card: IslandWindow, zone: UUID, picture: WindowPicture?, size: CGSize)?
    private var carryTimer: Timer?
    /// Two fingers have hold of a display's grid: the display, how far they have taken it, and where it was.
    private var swiping: (display: LayoutGridDisplay, scrub: ScrubGesture, start: CGFloat)?
    /// What the carried card shows now: its size and whether it shows its picture. They follow the zone it is over by steps: from the picture to the glyph it changes its face first,
    /// at the size it has, then its size; from the glyph to the picture its size first, then its face. `ghostSteps` counts the changes: a step of an earlier one does nothing.
    private var shown: (size: CGSize, picture: Bool) = (.zero, false)
    private var ghostSteps = 0
    private var ghostAnimation: Animation?
    /// Where the mouse holds the carried card, from its middle (as `ZoneWindowsModel` keeps it for the grid of one zone).
    private var grab: CGPoint = .zero
    private var carryMonitors: [Any] = []
    /// The text typed in the search bar (the same on every display), and which of the cards that match it is the one marked.
    private let search = LayoutGridSearch()
    /// Where the pointer was when the grid was asked for: the display it is on has the search bar.
    private var triggerPoint = CGPoint.zero
    /// Where the island stands on a display (Cocoa coordinates), asked when the grid is made; set by `AppContainer`.
    var islandShape: (ScreenInfo) -> CGRect? = { _ in nil }
    /// The grid of a display is scrolled to another screen of its layout: the island's picture of that layout moves the same way, by the same curve and in the same time
    /// (`MenuBarIsland.glide`, `follow`), as it does when the layout itself scrolls: from where the island's frame is (a glide that still runs, or the fingers' last place). The offsets are the layout's own (where the grid opened plus how far it has gone). Set by `AppContainer`.
    var onGlide: ((ScreenInfo, _ to: CGFloat) -> Void)?
    var onFollow: ((ScreenInfo, _ offset: CGFloat) -> Void)?
    /// How far each display's grid was scrolled when the search first moved it: it goes back there when the search ends.
    private var scrolledBySearch: [ObjectIdentifier: CGFloat]?
    private var matchIndex = 0
    private var appNames: [String: String] = [:]
    /// The pointer stays at the edge of a display while a card is carried: which display, which side (-1 left, 1 right), since when, and until when it waits before the next step.
    private var edge: (display: ObjectIdentifier, side: Int)?
    /// The fingers lead the grid (`LayoutGridLeading`) as they lead the grid of one zone (`ZoneWindowsOverlay`): where the pictures were when they took hold (`from`, as
    /// `ZoneWindowsModel.appear`), whether the grid was on its way to open then, how far up the fingers have gone since (in points; `leadSpan` of them are the whole way) and whether
    /// they have lifted. While it opens the pictures follow the fingers only once the real windows are away (`leadReady`).
    private var lead: (from: CGFloat, heading: Bool, travel: CGFloat, lifted: Bool)?
    private var leadReady = false
    private var leadSpan: CGFloat = 600
    private var leadScrub = ScrubGesture()
    /// Moves the pictures of every zone (`ZoneWindowsModel.appear`, the same in all): where they are now is its value.
    private lazy var driver = AppearDriver { [weak self] in self?.setAppear($0) }
    /// The cards take no pointer while they move (`ZoneWindowsModel.sliding`); each start of a move counts, so that only the end of the last one frees them.
    private var slideRun = 0
    /// Counts the times the grid began to close: the end of a closing slide that was taken back does nothing. The pictures are back and the windows are coming back: it closes to its end.
    private var closeRun = 0
    private var restoring = false
    private static let reorder = Animation.smooth(duration: 0.25)
    /// Counts the grids: what a grid asked for and comes late (pictures, the end of a slide) does nothing to the next one.
    private var run = 0

    /// When the slide in progress ends.
    private var slideEnds = Date.distantPast
    /// The layout's scroll follows the fingers, each step glided to in a moment. Not a spring: a spring keeps the speed it had and swings past a target that is near (or at the end of the way).
    private static let follow = Animation.easeOut(duration: 0.1)
    /// The motion of the layout's own scroll from one screen to the next.
    private static let scrollSlide = Animation.timingCurve(0.215, 0.61, 0.355, 1, duration: 0.3)
    private static let waitForWindows: TimeInterval = 0.3
    /// How near the pointer is to a display's left or right edge to count as at it, how long it stays there before the grid goes on to the next screen, and the same again for each
    /// screen after it.
    private static let edgeBand: CGFloat = 4
    /// A rectangle on a display, moved to where the user says that display stands on the desk (Settings): the arrow keys go to the display beside it there.
    private let deskRect: (CGRect) -> CGRect

    init(coordinator: StackCoordinator, screens: ScreenProviding, source: ZoneCardSource, snapshots: WindowSnapshotting, planner: ZonePlanner, mover: WindowMover,
         refresher: ZoneRefreshing, gapOf: @escaping (ScreenInfo) -> CGFloat, gain: @escaping () -> CGFloat, deskRect: @escaping (CGRect) -> CGRect) {
        self.deskRect = deskRect
        self.gain = gain
        self.coordinator = coordinator
        self.screens = screens
        self.source = source
        self.snapshots = snapshots
        self.planner = planner
        self.mover = mover
        self.refresher = refresher
        self.gapOf = gapOf
        keeper = ZoneCardsKeeper(coordinator: coordinator, source: source, snapshots: snapshots)
        search.onClear = { [weak self] in self?.exitSearch() }
        search.onChange = { [weak self] in self?.searchChanged() }
    }

    var isShown: Bool { phase != nil }

    /// The shortcut, the wheel button and the button of the island: the grid opens, or, open, closes; one that is closing opens again from where its pictures are.
    func toggle() {
        switch phase {
        case nil: show()
        case .opening, .open: hide()
        case .closing: if !restoring { closeRun += 1; goOpen() }
        }
    }

    // MARK: Led by the fingers

    /// The fingers take hold of the grid wherever it is: shut (up opens it), open (down closes it), and in the middle of opening or closing, from where the pictures are.
    func moveLead(by up: CGFloat, at time: TimeInterval) {
        // The first move of a swipe is the whole way the fingers went while its direction was decided, in one piece: the pictures do not jump that far, they go from where they are.
        let up = lead == nil ? up.sign == .minus ? -CGFloat.leastNonzeroMagnitude : .leastNonzeroMagnitude : up
        if lead == nil {
            leadScrub = ScrubGesture()
            switch phase {
            case nil:
                guard up > 0 else { return }
                let all = screens.screens()
                leadSpan = max((all.first { $0.cocoaFrame.contains(screens.pointerCocoa) } ?? all.first)?.axVisible.height ?? 600, 100)
                lead = (0, false, 0, false)
                show()
                if phase == nil { lead = nil }   // nothing to show
            case .opening: lead = (0, true, 0, false)   // opened another way, the windows still going: the pictures are the fingers' once they can move
            case .open:
                let now = driver.value
                guard up < 0 || now < 1 else { return }   // open and at rest: only a swipe down takes hold
                hold()
                lead = (now, true, 0, false)
            case .closing:
                guard !restoring else { return }
                let now = driver.value
                hold()
                closeRun += 1
                resume()
                lead = (now, false, 0, false)
            }
        }
        guard var current = lead else { return }
        leadScrub.add(up, at: time)
        current.travel = min(max(current.travel + up, -current.from * leadSpan), (1 - current.from) * leadSpan)
        lead = current
        if phase == .open || leadReady { follow(leadValue(current)) }
    }

    private func leadValue(_ lead: (from: CGFloat, heading: Bool, travel: CGFloat, lifted: Bool)) -> CGFloat {
        min(max(lead.from + lead.travel / leadSpan, 0), 1)
    }

    func endLead() {
        guard var current = lead else { return }
        current.lifted = true
        lead = current
        if phase == .open || leadReady {
            finishLead()
        } else if !current.heading, current.travel < ScrubGesture.dragShare * 100, !(leadScrub.isFlick && leadScrub.speed > 0) {
            reset()   // the pictures never came: nothing to take back
        }
    }

    /// The fingers lifted: the grid goes the way a fast flick sent it; or the way they took it, if that was far enough; or on to where it was going.
    private func finishLead() {
        guard let current = lead, phase == .open || phase == .opening else { return lead = nil }
        lead = nil
        leadReady = false
        let moved = current.travel / leadSpan
        let opens = leadScrub.isFlick ? leadScrub.speed > 0 : abs(moved) >= ScrubGesture.dragShare ? moved > 0 : current.heading
        if opens { goOpen() } else { hide() }
    }

    private func setAppear(_ value: CGFloat) {
        displays.forEach { $0.model.appear = value; $0.model.zones.forEach { $0.model.appear = value } }
    }

    private func slide(to value: CGFloat, then: @escaping () -> Void = {}) {
        slideEnds = Date().addingTimeInterval(AppearDriver.slideTime)
        setSliding(true)
        let mine = slideRun
        driver.slide(to: value) { [weak self] in
            if let self, slideRun == mine, value >= 1 { setSliding(false) }   // a slide taken over by another one, or a closing one, leaves the cards inert
            then()
        }
    }

    private func setSliding(_ value: Bool) {
        if value { slideRun += 1 }
        displays.forEach { $0.model.zones.forEach { if $0.model.sliding != value { $0.model.sliding = value } } }
    }

    /// The pictures go with the fingers; while they catch up with fingers that went on before the pictures could move, they glide to where the fingers are in the time that is left.
    private func follow(_ value: CGFloat) { driver.follow(to: value) }

    /// The pictures stop where they are, in the middle of a slide: the fingers have them from there.
    private func hold() {
        driver.hold()
        cancelCarry()   // the cards go inert under the fingers: a card in the air would never be let go
        setSliding(true)
    }

    // MARK: Opening

    func show() {
        guard phase == nil, !isBlocked(), !coordinator.isMoving else { return }
        let all = screens.screens()
        var plans: [LayoutGridPlan] = []
        for screen in all {
            guard let (geometry, side) = planner.strip(of: screen, among: all) else { continue }
            let area = screen.axVisible
            let offset = geometry.clamped(planner.viewport.offset(for: screen.key))
            let zones = geometry.zones(offset: offset).map { (id: $0.id, rect: $0.rect.offsetBy(dx: -area.minX, dy: -area.minY), cards: [IslandWindow]()) }
            if !zones.isEmpty { plans.append(LayoutGridPlan(screen: screen, side: side, offset: offset, rests: geometry.rests.map { $0 - offset }, zones: zones)) }
        }
        // Every window of a zone has a card (`allCards`): the pictures are asked for first, and the cards of every zone, which take a while, are read while they are taken.
        let refs = plans.flatMap(\.zones).flatMap { zone in coordinator.stacks[zone.id].map { stack in stack.tabs.compactMap { stack.refs[$0.id] } } ?? [] }
        var read = false
        func readCards() {
            for p in plans.indices { for z in plans[p].zones.indices { plans[p].zones[z].cards = source.allCards(of: plans[p].zones[z].id) } }
            read = true
        }
        if refs.isEmpty {
            readCards()
            guard plans.contains(where: { $0.zones.contains { !$0.cards.isEmpty } }) else { return }   // no card anywhere: nothing to show
        }
        phase = .opening
        triggerPoint = screens.pointerAX
        run += 1
        let mine = run
        snapshots.prepare()
        keeper.asked = Set(refs.map(\.id))
        // Whichever comes second, the pictures or the cards, puts the grid up.
        var taken: [CGWindowID: WindowPicture]?
        snapshots.snapshots(of: refs) { [weak self] pictures in
            guard let self, run == mine, phase == .opening else { return }
            if read { begin(plans, pictures: pictures) } else { taken = pictures }
        }
        guard !read else { return }
        readCards()
        if let taken { begin(plans, pictures: taken) }
    }

    /// The pictures are here: a grid is put over each display with each picture over its window.
    private func begin(_ plans: [LayoutGridPlan], pictures: [CGWindowID: WindowPicture]) {
        // The display the grid was asked for on has the search bar (and the room for it): the one the pointer was on, else the first.
        let searching = plans.firstIndex { screens.flip($0.screen.cocoaFrame).insetBy(dx: -2, dy: -2).contains(triggerPoint) } ?? 0
        displays = plans.enumerated().map { makeDisplay($1, pictures: pictures, searching: $0 == searching) }
        updateSearchCounts()
        coordinator.switchLocked = true
        let mine = run
        // A few frames for the window server to put the pictures on screen, then the real windows may go.
        DispatchQueue.main.asyncAfter(deadline: .now() + PanelSlideStage.settle) { [weak self] in
            guard let self, run == mine, phase == .opening else { return }
            park(plans) { [weak self] in
                guard let self, run == mine, phase == .opening else { return }
                ready()
            }
        }
    }

    private func makeDisplay(_ plan: LayoutGridPlan, pictures: [CGWindowID: WindowPicture], searching: Bool) -> LayoutGridDisplay {
        let area = plan.screen.axVisible
        let model = LayoutGridModel()
        model.size = area.size
        model.search = search
        model.barGap = gapOf(plan.screen)
        model.showsSearch = searching
        if searching, let island = islandShape(plan.screen) {
            let frame = plan.screen.cocoaFrame
            model.islandCover = CGRect(x: island.minX - frame.minX, y: frame.maxY - island.maxY, width: island.width, height: island.height)
        }
        model.rests = plan.rests
        model.origin = area.origin
        model.focused = coordinator.focusedZoneID
        model.onClose = { [weak self] in self?.hide() }
        let gap = gapOf(plan.screen)
        model.zones = plan.zones.map { zone in
            // The grid of one zone, as `ZoneWindowsOverlay` sets it up.
            let grid = ZoneWindowsModel()
            grid.cards = zone.cards
            grid.size = zone.rect.size
            grid.gap = gap
            grid.front = zone.cards.first(where: \.isActive)?.id
            // Only the zone that has the focus marks its card with the focus.
            grid.tracksFocus = zone.id == coordinator.focusedZoneID
            grid.highlighted = grid.tracksFocus ? grid.front ?? zone.cards.first?.id : nil
            grid.carrier = self
            grid.sliding = true   // the cards move from the start (a slide, or the fingers), and rest only at the end of the opening slide
            let waits = coordinator.stacks[zone.id]?.isParked ?? true
            for card in zone.cards {
                guard let id = card.windowID, let picture = pictures[id] else { continue }
                grid.pictures[card.id] = picture
                // A window out of sight waits at the display's edge: it counts as standing in its zone, where the layout shows it.
                grid.origins[card.id] = waits ? CGRect(origin: .zero, size: zone.rect.size)
                    : picture.frame.offsetBy(dx: -area.minX - zone.rect.minX, dy: -area.minY - zone.rect.minY)
            }
            let id = zone.id
            grid.chosenAnywhere = false
            grid.onPointed = { [weak self, weak grid] in self?.pointedChanged(in: grid) }
            grid.onChoose = { [weak self] card in self?.choose(card, in: id) }
            grid.onPerform = { [weak self] action, card in self?.perform(action, on: card, in: id) }
            grid.onToggleStart = { [weak self] card in self?.toggleStart(card, in: id) }
            grid.onMove = { [weak self] card, target in self?.reorder(card, to: target, in: id) }
            grid.onClose = { [weak self] in self?.hide() }
            return LayoutGridZone(id: zone.id, rect: zone.rect, model: grid)
        }
        model.zones.forEach { $0.model.squeeze = model.gridScale }   // the grid is drawn lower for the search bar: the titles and buttons of the cards are not (`ZoneWindowsCard`)
        // The panel is the whole display, the menu bar and the Dock too, so that nothing cuts the shadows of the cards; the grid lies in its usable area.
        let frame = plan.screen.cocoaFrame, whole = screens.flip(frame)
        model.inset = CGPoint(x: area.minX - whole.minX, y: area.minY - whole.minY)
        model.wholeSize = whole.size
        let panel = ZoneWindowsPanel(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.animationBehavior = .none
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary]
        let host = ZoneWindowsHostingView(rootView: LayoutGridView(model: model))
        host.sizingOptions = []
        panel.contentView = host
        panel.setFrame(frame, display: true)
        panel.orderFrontRegardless()
        return LayoutGridDisplay(screen: plan.screen, frame: screens.flip(plan.screen.cocoaFrame), area: area, offset: plan.offset, model: model, panel: panel)
    }

    /// The real windows of the zones in view wait at the displays' edge, as they do while the layout scrolls; `then` runs once they have gone. A display without a side to wait
    /// at (its layout has no screen beyond the edges then) keeps its windows, and the pictures move over them.
    private func park(_ plans: [LayoutGridPlan], then: @escaping () -> Void) {
        for plan in plans {
            guard let side = plan.side else { continue }
            for zone in plan.zones {
                guard let stack = coordinator.stacks[zone.id], !stack.isParked else { continue }
                let waiting = Parking.frame(for: stack.rect, on: plan.screen.cocoaFrame, side: side).origin
                for ref in stack.refs.values {
                    parked.append((ref, stack.frame.origin))
                    mover.move(ref, to: waiting)
                }
            }
        }
        guard !parked.isEmpty else { return then() }
        coordinator.isScrolling = true
        holding = true
        refresher?.refreshPresenters()   // the notches (and the island) give way, while the windows are on their way: nothing else of a refresh is needed with the zones held
        wait(then: then)
    }

    /// Runs `then` once the windows asked to move have moved, or after a moment if one does not answer.
    private func wait(then: @escaping () -> Void) {
        var done = false
        let finish = { guard !done else { return }; done = true; then() }
        mover.flush(then: finish)
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.waitForWindows, execute: finish)
    }

    /// The pictures are over the windows and the windows are away: the grid opens, or, led by the fingers, follows them from here.
    private func ready() {
        guard phase == .opening, !displays.isEmpty else { return reset() }
        guard var current = lead else { return goOpen() }
        leadReady = true
        // The fingers lifted while the windows were taken away: the grid goes the way they sent it.
        guard !current.lifted else { return finishLead() }
        // The fingers went on while the windows were taken away: that way is not followed (the pictures would jump to where the fingers are). They are the fingers' from here, from
        // where they stand now; the swipe up that began it counts as the grid being on its way to open.
        current.travel = 0
        current.heading = true
        lead = current
        leadScrub = ScrubGesture()
    }

    /// The windows of every zone go to their cards, from where the pictures are, and the grid is the keys' and the mouse's.
    private func goOpen() {
        guard phase != nil, !displays.isEmpty else { return }
        resume()
        slide(to: 1) { [weak self] in
            guard let self, phase == .open else { return }
            revealOffView()
            coordinator.holdsStill = true   // a window closed from a card turns it into the card of a closed window
        }
    }

    private func resume() {
        phase = .open
        (displays.first { $0.model.showsSearch } ?? keyDisplay())?.panel.makeKey()   // the keys are the grid's now
        watch()
        if timer == nil { timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in self?.refreshSpread() } }
    }

    /// The zones of the screens beyond the edges are put in one after the other, a few frames apart, once the grid is open: all of them in one go held the main thread for a frame or two.
    private func revealOffView() {
        let mine = run
        var delay = 0.0
        for display in displays {
            for zone in display.model.zones where !display.model.offViewDrawn.contains(zone.id) {
                delay += Self.revealGap
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self, weak display] in
                    guard let self, let display, run == mine, phase == .open else { return }
                    display.model.offViewDrawn.insert(zone.id)
                }
            }
        }
    }

    private static let revealGap: TimeInterval = 0.03

    /// Every zone at once: the grid is about to scroll, and what it scrolls to must be there.
    private func revealAllOffView() { displays.forEach { $0.model.offViewDrawn = Set($0.model.zones.map(\.id)) } }

    /// The display the pointer is on, else the first one.
    /// (A pointer at a display's right or bottom edge lies on the edge of its frame, which `contains` leaves out: a little room is given.)
    private func display(at point: CGPoint) -> LayoutGridDisplay? { displays.first { $0.frame.insetBy(dx: -2, dy: -2).contains(point) } }
    private func keyDisplay() -> LayoutGridDisplay? { display(at: screens.pointerAX) ?? displays.first }

    // MARK: Scrolling

    /// A display's grid scrolls to another rest.
    private func scroll(_ display: LayoutGridDisplay, to rest: CGFloat) {
        guard phase == .open, abs(rest - display.model.shift) > 0.5 else { return }
        revealAllOffView()
        onGlide?(display.screen, display.offset + rest)
        withAnimation(Self.scrollSlide) { display.model.shift = rest }
    }

    /// The mouse wheel, a notch for a screen, and two fingers sideways, a swipe for a screen, on the display the pointer is on.
    private func wheel(_ event: NSEvent) {
        if event.hasPreciseScrollingDeltas { return swipe(event) }
        guard let display = keyDisplay() else { return }
        scroll(display, to: display.model.rest(steps: PagedScroll.notch(event.scrollingDeltaY != 0 ? event.scrollingDeltaY : -event.scrollingDeltaX)))
    }

    /// Two fingers sideways: the grid follows them, and, when they lift, comes to rest at the screen they took it to (a flick goes on to the next one that way).
    private func swipe(_ event: NSEvent) {
        guard event.momentumPhase.isEmpty else { return }   // the fingers have settled it already
        if swiping == nil || event.phase.contains(.began) {
            guard let display = keyDisplay() else { return }
            revealAllOffView()
            swiping = (display, ScrubGesture(), display.model.shift)
        }
        guard var current = swiping else { return }
        let model = current.display.model
        let moved = event.scrollingDeltaX * gain()
        current.scrub.add(moved, at: event.timestamp)
        swiping = current
        let lowest = model.rests.min() ?? 0, highest = model.rests.max() ?? 0
        let followed = min(max(model.shift - moved, lowest), highest)
        onFollow?(current.display.screen, current.display.offset + followed)
        withAnimation(Self.follow) { model.shift = followed }
        guard event.phase.contains(.ended) || event.phase.contains(.cancelled) else { return }
        swiping = nil
        // Where it would come to rest: the nearest screen to where the fingers would have taken it; a flick goes on to the next one that way at least.
        let projected = model.shift - current.scrub.landing + current.scrub.offset
        var target = model.rests.min { abs($0 - projected) < abs($1 - projected) } ?? model.shift
        if current.scrub.isFlick, abs(target - current.start) < 0.5 { target = model.rest(steps: current.scrub.speed > 0 ? -1 : 1) }
        onGlide?(current.display.screen, current.display.offset + target)
        withAnimation(Self.scrollSlide) { model.shift = target }
    }

    // MARK: Search

    private func updateSearchCounts() {
        search.zones = displays.reduce(0) { $0 + $1.model.zones.count }
        search.windows = displays.reduce(0) { $0 + $1.model.places.filter { $0.card.windowID != nil }.count }
    }

    /// The cards, on every display and in every zone (those of the screens beyond the edges too), whose title (or the name of its app) matches what is typed, the best match first
    /// (`WindowSearch`): those of apps that are not open too (the name of the app), though they are not counted.
    private var matches: [(display: LayoutGridDisplay, place: LayoutGridPlace)] {
        let all = displays.flatMap { display in display.model.places.map { (display: display, place: $0) } }
        return WindowSearch.matches(search.query, in: all.map(\.place.card.name), others: all.map { appName(of: $0.place.card.bundleID) }).map { all[$0] }
    }

    /// The name of the app a window belongs to, for a search that has the app's name instead of the window's title (asked once for each app).
    private func appName(of bundleID: String) -> String {
        if let known = appNames[bundleID] { return known }
        let name = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID).map { FileManager.default.displayName(atPath: $0.path).replacingOccurrences(of: ".app", with: "") } ?? ""
        appNames[bundleID] = name
        return name
    }

    /// The cards that do not match are dimmed; with nothing typed, none is.
    private func applyMatching() {
        let ids: Set<String>? = search.query.trimmingCharacters(in: .whitespaces).isEmpty ? nil : Set(matches.map(\.place.card.id))
        displays.forEach { $0.model.zones.forEach { if $0.model.matching != ids { $0.model.matching = ids } } }
    }

    /// What is typed changed: the first match is the card to be chosen (its screen is scrolled to); with nothing typed the grids are as they were before the search.
    private func searchChanged() {
        applyMatching()
        guard !search.query.trimmingCharacters(in: .whitespaces).isEmpty else { return endSearch() }
        matchIndex = 0
        markMatch()
    }

    /// The search ends: the text goes, the keys are given back to the grid, and each display shows the screens it showed before the search moved it.
    private func exitSearch() {
        search.query = ""
        displays.forEach { $0.panel.makeFirstResponder(nil) }
        search.blurToken += 1
        searchChanged()
    }

    /// The cards pass under the pointer while the grid scrolls for the search: they must not take the mark from the match (the animation lasts 0.3 s).
    private func quietHover() {
        let zones = displays.flatMap(\.model.zones).map(\.model)
        zones.forEach { $0.ignoresHover = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { zones.forEach { $0.ignoresHover = false } }
    }

    private func endSearch() {
        displays.forEach { $0.model.select(nil) }
        guard let saved = scrolledBySearch else { return }
        scrolledBySearch = nil
        for display in displays { if let shift = saved[ObjectIdentifier(display)] { scroll(display, to: shift) } }
        quietHover()
    }

    private func stepMatch(by step: Int) {
        let count = matches.count
        guard count > 0 else { return }
        matchIndex = (matchIndex + step + count) % count
        markMatch()
    }

    private func markMatch() {
        let found = matches
        guard !found.isEmpty else { return }
        let hit = found[matchIndex % found.count]
        if scrolledBySearch == nil { scrolledBySearch = Dictionary(uniqueKeysWithValues: displays.map { (ObjectIdentifier($0), $0.model.shift) }) }
        displays.forEach { $0.model.select(nil) }
        hit.display.model.select(hit.place)
        scroll(hit.display, to: hit.display.model.shiftShowing(hit.place))
        quietHover()
    }

    /// A key that is not one of the grid's: typed in the search bar (not with Command or Control held, and not the function keys, whose characters are private ones).
    /// shortcut: the characters the key gives, so no input methods or dead keys; the text field does that, and gets the keys back with the next one.
    private func type(_ event: NSEvent) {
        guard phase == .open, !event.modifierFlags.contains(.command), !event.modifierFlags.contains(.control), let text = event.characters,
              text.unicodeScalars.allSatisfy({ $0.value >= 0x20 && $0.value != 0x7F && !(0xF700...0xF8FF).contains($0.value) }) else { return }
        search.query += text
        searchChanged()
        search.focusToken += 1
    }

    // MARK: Arrow keys

    /// The card to be chosen and its display: where the pointer or the arrow keys are, else the card with the focus, else the first card there is.
    private func located() -> (display: LayoutGridDisplay, place: LayoutGridPlace)? {
        // A card the pointer or the arrow keys are on, on any display, comes before the card with the focus (else a key could never leave a display that has the focus).
        for display in displays { if let place = display.model.pointed { return (display, place) } }
        for display in displays { if let place = display.model.current { return (display, place) } }
        for display in displays { if let place = display.model.places.first { return (display, place) } }
        return nil
    }

    /// An arrow key: the card to be chosen goes to the nearest card that way, in its zone, in another zone of the display (the display's grid scrolls to it) or, when there is
    /// none, to the nearest card in view on another display.
    private func movePointer(toward direction: ZoneDirection) {
        guard phase == .open, let (display, from) = located() else { return }
        if let next = display.model.neighbour(of: from, toward: direction) {
            display.model.select(next)
            scroll(display, to: display.model.shiftShowing(next))
            return
        }
        func global(_ place: LayoutGridPlace, in d: LayoutGridDisplay) -> CGRect { deskRect(place.rect.offsetBy(dx: d.area.minX - d.model.shift, dy: d.area.minY)) }
        var candidates: [(display: LayoutGridDisplay, place: LayoutGridPlace)] = []
        for other in displays where other !== display { candidates += other.model.places.filter(other.model.isInView).map { (other, $0) } }
        let origin = global(from, in: display)
        // On the desk a display is beside this one only where their heights meet (the display below lies under, not beside): left and right need a card at the height of this one.
        let horizontal = direction == .left || direction == .right
        let list = candidates.enumerated().map { (id: $0.offset, rect: global($0.element.place, in: $0.element.display), number: $0.offset) }
            .filter { !horizontal || min($0.rect.maxY, origin.maxY) > max($0.rect.minY, origin.minY) }
        guard let index = ZoneNeighbour.nearest(to: origin, number: 0, among: list, toward: direction) else { return }
        display.model.select(nil)
        candidates[index].display.model.select(candidates[index].place)
    }

    private var syncingPointers = false

    /// One card is the one to be chosen in the whole grid, the last one the pointer or the arrow keys went to: when a zone marks one, no other zone, on any display, does.
    private func pointedChanged(in changed: ZoneWindowsModel?) {
        guard !syncingPointers else { return }
        syncingPointers = true
        defer { syncingPointers = false }
        let zones = displays.flatMap(\.model.zones).map(\.model)
        if let changed, changed.pointed != nil { for other in zones where other !== changed { other.pointed = nil } }
        let any = zones.contains { $0.pointed != nil }
        for zone in zones { zone.chosenAnywhere = any }
    }

    private func choosePointed() {
        guard phase == .open, let (_, place) = located() else { return }
        choose(place.card, in: place.zone.id)
    }

    // MARK: Cards

    /// A window's card closes the grid on that window. The card of an app that is not open opens the app and the grid stays: it closes on the window once it has come
    /// into the zone, or stays open if the app does not come within a while.
    private func choose(_ card: IslandWindow, in zone: UUID) {
        guard phase == .open else { return }
        guard card.windowID == nil else { return hide(choosing: (zone, card)) }
        guard opening == nil else { return }
        opening = (zone, card.bundleID, Date())
        source.choose(card, in: zone)
    }

    private func perform(_ action: IslandCardAction, on card: IslandWindow, in zone: UUID) {
        guard phase == .open else { return }
        source.perform(action, on: card, in: zone)
        // The window needs a moment to go (or to be hidden): the cards are read again then.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in self?.refresh() }
    }

    private func toggleStart(_ card: IslandWindow, in zone: UUID) {
        guard phase == .open else { return }
        source.toggleStart(card, in: zone)
        refresh()
    }

    private func zoneModel(_ id: UUID) -> ZoneWindowsModel? { displays.lazy.compactMap { $0.model.zones.first { $0.id == id }?.model }.first }

    /// The cards a zone shows: what it has, less the cards carried away from it and plus those carried to it.
    private func adjusted(_ cards: [IslandWindow], in zone: UUID) -> [IslandWindow] {
        var result = cards.filter { card in !moves.contains { $0.card.id == card.id && $0.origin == zone && $0.target != zone } }
        for move in moves where move.target == zone && move.origin != zone && !result.contains(where: { $0.id == move.card.id }) {
            result.insert(move.card, at: min(move.index, result.count))
        }
        return result
    }

    /// `card`, carried over the grid of its zone, is put in the place of `target`: the zone's windows stand in the new order, and the cards are read again.
    private func reorder(_ card: IslandWindow, to target: IslandWindow, in zone: UUID) {
        guard phase == .open else { return }
        source.move(card, toPlaceOf: target, in: zone)
        reload(zone)
    }

    /// The cards `zone` shows, as it has them now: a zone with none left shows its empty places.
    private func reload(_ zone: UUID) {
        guard let grid = zoneModel(zone) else { return }
        if !keeper.refresh(grid, zone: zone, animated: Self.reorder, adjust: { [weak self] in self?.adjusted($0, in: zone) ?? $0 }), !grid.cards.isEmpty {
            withAnimation(Self.reorder) { grid.cards = [] }
        }
    }

    /// The cards of every zone as it has them now (a window that came, went or was moved): a zone with none left shows its empty places. The app that was asked to
    /// open: the grid closes on its window once it is in the zone.
    private func refresh() {
        guard phase == .open, Date() >= slideEnds else { return }   // asking every zone for its cards takes a while: not in the middle of a slide
        displays.forEach { $0.model.zones.forEach { reload($0.id) } }
        finishRefresh()
    }

    /// The same, for the timer: the zones are read one after the other over a fraction of its period (each is read as often as before), not all in one go. Asking for the cards of
    /// every zone at once held the main thread for 10 to 16 ms, a frame or two of the grid's drawing every half second.
    private func refreshSpread() {
        guard phase == .open, Date() >= slideEnds else { return }
        let zones = displays.flatMap { $0.model.zones.map(\.id) }
        let gap = Self.refreshSpan / Double(zones.count + 1)
        for (index, zone) in zones.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + gap * Double(index)) { [weak self] in
                guard let self, phase == .open, Date() >= slideEnds else { return }
                reload(zone)
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.refreshSpan) { [weak self] in
            guard let self, phase == .open, Date() >= slideEnds else { return }
            finishRefresh()
        }
    }

    /// How long the timer's reading of the zones is spread over (less than its period, so that one pass is over before the next begins).
    private static let refreshSpan: TimeInterval = 0.4

    private func finishRefresh() {
        updateSearchCounts()
        applyMatching()
        guard let current = opening else { return }
        if let zone = displays.lazy.flatMap(\.model.zones).first(where: { $0.id == current.zone }),
           let card = zone.model.cards.first(where: { $0.bundleID == current.bundleID && $0.windowID != nil }) {
            opening = nil
            zone.model.origins[card.id] = CGRect(origin: .zero, size: zone.rect.size)   // it stands as the zone's front window: the card grows to fill the zone
            hide(choosing: (zone.id, card))
        } else if Date().timeIntervalSince(current.since) > 15 {
            opening = nil
        }
    }

    // MARK: Carrying

    /// A card is carried: it is put in the zone the pointer is over at once (as the last card of it, or, in its own zone, in the place of the card under the pointer), the cards
    /// of that zone and of the one it left make room for it, and the card takes the size of the places there. It goes to its zone for good when the grid closes.
    func carryBegan(_ card: IslandWindow, from zone: ZoneWindowsModel) {
        guard phase == .open, let (display, home) = displays.lazy.compactMap({ d in d.model.zones.first { $0.model === zone }.map { (d, $0) } }).first,
              let index = zone.cards.firstIndex(where: { $0.id == card.id }), zone.cells.indices.contains(index) else { return }
        let point = screens.pointerAX, cell = zone.cells[index]
        let inGrid = display.model.inGrid(CGPoint(x: point.x - display.area.minX, y: point.y - display.area.minY))
        grab = CGPoint(x: inGrid.x + display.model.shift - home.rect.minX - cell.midX, y: inGrid.y - home.rect.minY - cell.midY)
        carrying = (card, home.id, zone.pictures[card.id], cell.size)
        shown = (cell.size, LayoutGridGhost.fits(zone.pictures[card.id], in: cell.size))
        edge = nil
        carryTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in self?.carryTick() }
        // The card's own gesture dies when its card goes to another zone (its view goes with it): the mouse is followed here too, and its end is waited for a moment, so that the
        // gesture of a card that is still there ends first.
        carryMonitors = [
            NSEvent.addLocalMonitorForEvents(matching: .leftMouseDragged) { [weak self] event in self?.carryMoved(); return event },
            NSEvent.addLocalMonitorForEvents(matching: .leftMouseUp) { [weak self] event in
                DispatchQueue.main.async { self?.endCarry() }
                return event
            },
        ].compactMap { $0 }
        carryMoved()
    }

    func carryMoved() {
        guard var carried = carrying, phase == .open else { return }
        let point = screens.pointerAX
        guard let display = display(at: point) else { displays.forEach { $0.model.carry = nil }; return }
        displays.filter { $0 !== display }.forEach { $0.model.carry = nil }
        let at = display.model.inGrid(CGPoint(x: point.x - display.area.minX, y: point.y - display.area.minY))
        // The card is where the mouse holds it, and it is the middle of the card that says which place it is over, as in the grid of one zone.
        let middle = CGPoint(x: at.x - grab.x, y: at.y - grab.y)
        var model = zoneModel(carried.zone), sized = false
        if let zone = display.model.zone(at: at) {
            model = zone.model
            let local = CGPoint(x: middle.x + display.model.shift - zone.rect.minX, y: middle.y - zone.rect.minY)
            // The place is the one the pointer is over, in the grid the zone's cards make with this one among them (an empty cell is the end). The cards make room for it there.
            let pointer = CGPoint(x: at.x + display.model.shift - zone.rect.minX, y: at.y - zone.rect.minY)
            let here = zone.model.cards.contains { $0.id == carried.card.id }
            let index = ZoneGrid.place(at: pointer, count: zone.model.cards.count + (here ? 0 : 1), in: zone.model.size, gap: zone.model.gap)
            if zone.id != carried.zone {
                put(carried, in: zone, at: index ?? zone.model.cards.count)
                carried.zone = zone.id
            } else if let i = moves.firstIndex(where: { $0.card.id == carried.card.id }) {
                // Carried here from another zone: it stands where the pointer is among the cards, and they make room.
                if let index, index != moves[i].index { moves[i].index = index; reload(zone.id) }
            } else if let index, zone.model.cards.indices.contains(index), zone.model.cards[index].id != carried.card.id {
                // In its own zone it takes the place of the card under the pointer, as in the grid of one zone.
                reorder(carried.card, to: zone.model.cards[index], in: zone.id)
            }
            if let index = zone.model.cards.firstIndex(where: { $0.id == carried.card.id }), zone.model.cells.indices.contains(index), zone.model.cells[index].size != carried.size {
                // The card takes the size of the places of the zone, by an animation; where it is held keeps its share of the card.
                let size = zone.model.cells[index].size
                grab = CGPoint(x: grab.x * size.width / max(carried.size.width, 1), y: grab.y * size.height / max(carried.size.height, 1))
                carried.size = size
                sized = true
            }
            zone.model.carried = carried.card.id
            // Where the card is let go, its picture goes on from here to its place.
            var still = Transaction()
            still.disablesAnimations = true
            withTransaction(still) { zone.model.carriedAt = local }
            carrying = carried
        }
        guard let model else { return }
        if sized { retarget(to: carried.size, picture: carried.picture) }
        let ghost = LayoutGridGhost(card: carried.card, picture: carried.picture, size: shown.size, at: CGPoint(x: at.x - grab.x, y: at.y - grab.y), showsPicture: shown.picture, model: model)
        if let animation = ghostAnimation {
            ghostAnimation = nil
            withAnimation(animation) { display.model.carry = ghost }
        } else {
            var still = Transaction()
            still.disablesAnimations = true
            withTransaction(still) { display.model.carry = ghost }
        }
    }

    /// The card is to be of `size` (the places of the zone it came to), with the face that goes with it.
    private func retarget(to size: CGSize, picture: WindowPicture?) {
        ghostSteps += 1
        let mine = ghostSteps
        let fits = LayoutGridGhost.fits(picture, in: size)
        let sizing = Animation.smooth(duration: 0.25), facing = Animation.easeOut(duration: 0.15)
        func later(_ delay: TimeInterval, _ change: @escaping () -> Void, _ animation: Animation) {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self, ghostSteps == mine, carrying != nil else { return }
                change()
                ghostAnimation = animation
                carryMoved()
            }
        }
        if fits == shown.picture {
            shown = (size, fits)
            ghostAnimation = sizing
        } else if !fits {
            shown.picture = false   // the glyph first, at the size it has
            ghostAnimation = facing
            later(0.15, { [self] in shown.size = size }, sizing)
        } else {
            shown.size = size   // the size first, then the picture
            ghostAnimation = sizing
            later(0.25, { [self] in shown.picture = true }, facing)
        }
    }

    /// The card goes to `zone` from the zone it stands in now: the two zones show their cards as they will have them.
    private func put(_ carried: (card: IslandWindow, zone: UUID, picture: WindowPicture?, size: CGSize), in zone: LayoutGridZone, at index: Int) {
        var move = moves.first { $0.card.id == carried.card.id } ?? LayoutGridMove(card: carried.card, origin: carried.zone, target: carried.zone, index: index)
        moves.removeAll { $0.card.id == carried.card.id }
        move.target = zone.id
        move.index = index
        if move.target != move.origin { moves.append(move) }
        zone.model.pictures[carried.card.id] = carried.picture
        // The card is taken out of the zone it leaves while it is still hidden there: it leaves no silhouette.
        reload(carried.zone)
        reload(zone.id)
        zoneModel(carried.zone)?.carried = nil
    }

    /// The pointer touches the left or the right edge of a display: its grid goes on to the next screen that way at once, one screen for each touch (the pointer has to leave the
    /// edge and touch it again for the next).
    private func carryTick() {
        guard carrying != nil, phase == .open else { return }
        let point = screens.pointerAX
        guard let display = display(at: point) else { edge = nil; return }
        let side = point.x <= display.frame.minX + Self.edgeBand ? -1 : point.x >= display.frame.maxX - Self.edgeBand ? 1 : 0
        guard side != 0 else { edge = nil; return }
        if let current = edge, current.display == ObjectIdentifier(display), current.side == side { return }
        edge = (ObjectIdentifier(display), side)
        scroll(display, to: display.model.rest(steps: side))
        carryMoved()
    }

    func carryEnded(_ card: IslandWindow, from zone: ZoneWindowsModel) { endCarry() }

    /// The mouse is let go: the card stays where it was put. Let go off every display, it goes back to its zone.
    private func endCarry() {
        guard let carried = carrying else { return }
        let off = display(at: screens.pointerAX) == nil
        carryTimer?.invalidate()
        carryTimer = nil
        carryMonitors.forEach { NSEvent.removeMonitor($0) }
        carryMonitors = []
        carrying = nil
        edge = nil
        guard phase == .open else { return cancelCarry() }
        if off {
            // Let go off every display: it goes back to its zone.
            cancelCarry()
            if let move = moves.first(where: { $0.card.id == carried.card.id }) {
                moves.removeAll { $0.card.id == carried.card.id }
                reload(move.target)
                reload(move.origin)
            }
            return
        }
        // The card itself goes from where it was let go to its place, as in the grid of one zone, and stands there in the place of its hidden twin.
        guard let display = displays.first(where: { $0.model.carry != nil }), let ghost = display.model.carry,
              let zone = display.model.zones.first(where: { $0.id == carried.zone }), let index = zone.model.cards.firstIndex(where: { $0.id == carried.card.id }),
              zone.model.cells.indices.contains(index) else { return cancelCarry() }
        let cell = zone.model.cells[index]
        var landed = ghost
        landed.at = CGPoint(x: zone.rect.minX + cell.midX - display.model.shift, y: zone.rect.minY + cell.midY)
        landed.lifted = false
        landed.size = cell.size
        landed.showsPicture = ghost.picture != nil   // where it stands it is the window's picture again
        withAnimation(Self.reorder) { display.model.carry = landed }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            guard let self, carrying == nil else { return }
            var still = Transaction()
            still.disablesAnimations = true
            withTransaction(still) { self.cancelCarry() }
        }
    }

    private func cancelCarry() {
        carryTimer?.invalidate()
        carryTimer = nil
        carryMonitors.forEach { NSEvent.removeMonitor($0) }
        carryMonitors = []
        carrying = nil
        edge = nil
        for display in displays {
            // Written only when something changes: an observed property tells SwiftUI at every write, and the whole grid would be worked out again as the grid closes.
            if display.model.carry != nil { display.model.carry = nil }
            display.model.zones.forEach { if $0.model.carried != nil { $0.model.carried = nil } }
        }
    }

    // MARK: Closing

    /// The other way round: the pictures slide back over the places of the windows, the real windows come back and the grids fade away.
    func hide(choosing chosen: (zone: UUID, card: IslandWindow)? = nil) {
        if phase == .opening {
            guard !displays.isEmpty else { return reset() }   // its pictures have not come yet
            phase = .open
        }
        guard phase == .open else { return }
        phase = .closing
        coordinator.holdsStill = false
        displays.forEach { $0.model.offViewDrawn = [] }
        lead = nil
        leadReady = false
        cancelCarry()
        stopWatching()
        timer?.invalidate()
        timer = nil
        if let chosen { zoneModel(chosen.zone)?.front = chosen.card.id }   // its picture lies over the others as they fly back
        closeRun += 1
        let mine = run, close = closeRun
        slide(to: 0) { [weak self] in
            guard let self, run == mine, close == closeRun else { return }   // taken back meanwhile
            restore(choosing: chosen)
        }
    }

    private func restore(choosing chosen: (zone: UUID, card: IslandWindow)?) {
        restoring = true
        let scrolled = displays.filter { abs($0.model.shift) > 0.5 }
        let needsWait = !parked.isEmpty || !scrolled.isEmpty
        if !scrolled.isEmpty {
            // A grid was scrolled to another screen: its layout stays there. The zones are worked out for it, and every window goes to where its zone is now.
            scrolled.forEach { planner.viewport.set($0.offset + $0.model.shift, for: $0.screen.key) }
            release()
            for zone in displays.flatMap(\.model.zones) {
                guard let stack = coordinator.stacks[zone.id] else { continue }
                stack.refs.values.forEach { mover.move($0, to: stack.frame.origin) }
            }
        } else {
            parked.forEach { mover.move($0.ref, to: coordinator.stack(containing: $0.ref.id)?.frame.origin ?? $0.home) }
        }
        let mine = run
        let done = { [weak self] in
            guard let self, run == mine, phase == .closing else { return }
            // Nothing carried, chosen or scrolled: the zones are as they were, and are laid out again once the grids are gone (`reset`), not before their fade.
            release(refreshing: !moves.isEmpty || chosen != nil || !scrolled.isEmpty)
            // The cards carried to another zone go there; then the window chosen is put in front, as the grid of one zone does.
            for move in moves {
                source.send(move.card, from: move.origin, to: move.target)
                // It went last in its zone: it goes to the place it was carried to.
                let cards = source.allCards(of: move.target)
                if let at = cards.firstIndex(where: { $0.id == move.card.id }), move.index < at { source.move(move.card, toPlaceOf: cards[move.index], in: move.target) }
            }
            moves = []
            if let chosen { activate(chosen.card, in: chosen.zone) }
            // The real windows stand where they were: the grids fade away over them.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) { [weak self] in
                guard let self, run == mine else { return }
                let panels = displays.map(\.panel)
                NSAnimationContext.runAnimationGroup({ context in
                    context.duration = 0.12
                    panels.forEach { $0.animator().alphaValue = 0 }
                }, completionHandler: { [weak self] in if self?.run == mine { self?.reset() } })
            }
        }
        if needsWait { wait(then: done) } else { done() }
    }

    /// The window of the card chosen is put in front, as it stands (no slide: its picture has grown to be the window), as the grid of one zone does. A zone that is out of
    /// sight where the grid closed is chosen as a click on its card in the island chooses it: the layout scrolls to it.
    private func activate(_ card: IslandWindow, in zone: UUID) {
        guard let stack = coordinator.stacks[zone], let id = card.windowID, stack.refs[id] != nil, !stack.isParked else { return source.choose(card, in: zone) }
        if !card.isActive { coordinator.select(id, in: stack) }
        coordinator.focus(zone: zone)
    }

    /// The windows are back: the zones are free again. Not `refreshing`, they are laid out again by the next `release` (`holding` stays).
    private func release(refreshing: Bool = true) {
        parked = []
        coordinator.switchLocked = false
        // The zones are given back once; the refresh that follows may come later (after the fade), and must not give them back again to a scroll that started meanwhile.
        if holding {
            holding = false
            coordinator.isScrolling = false
            laysOutLater = true
        }
        guard refreshing, laysOutLater else { return }
        laysOutLater = false
        refresher?.refreshZones()
    }

    /// Everything goes back as it was, at once: the windows too.
    private func reset() {
        coordinator.holdsStill = false
        search.query = ""
        scrolledBySearch = nil
        stopWatching()
        timer?.invalidate()
        timer = nil
        cancelCarry()
        opening = nil
        moves = []
        keeper.asked = []
        if !parked.isEmpty {
            parked.forEach { mover.move($0.ref, to: $0.home) }
            mover.flush {}
        }
        displays.forEach { $0.panel.orderOut(nil) }
        release()
        displays = []
        phase = nil
        lead = nil
        leadReady = false
        driver.reset()
        restoring = false
        leadScrub = ScrubGesture()
        run += 1
    }

    // MARK: Watching

    private func watch() {
        guard monitors.isEmpty else { return }
        let clicks: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        monitors = [
            NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in if event.keyCode == 53 { self?.hide() } },
            // The arrow keys move the mark (not while searching: they are the text field's then), Return chooses, Escape ends the search (the grid stays), then closes; Tab goes to the next match, other keys are typed in the search bar (by its text field, or by hand when a click took the keys from it, which it then gets back) and not let through to the window behind.
            NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self, displays.contains(where: { $0.panel === event.window }) else { return event }
                // The search bar's text field has the keys while it is the first responder (it is, unless a click took them): it is let have the ones that are not the grid's.
                let field = event.window?.firstResponder as? NSText
                switch event.keyCode {
                case 53: if field != nil || !search.query.isEmpty { exitSearch() } else { hide() }   // the search first, then the grid
                case 36, 76:
                    if (field as? NSTextInputClient)?.hasMarkedText() == true { return event }   // an input method's choice is made with Return
                    choosePointed()
                case 123, 124, 125, 126:
                    // While searching the arrow keys are the text field's (the caret goes along the text); only with no search do they go from card to card.
                    if field != nil { return event }
                    if !search.query.isEmpty { search.focusToken += 1; break }   // a click took the keys from the field: it has them back for the next key
                    movePointer(toward: [123: .left, 124: .right, 125: .down, 126: .up][event.keyCode] ?? .left)
                case 48: stepMatch(by: event.modifierFlags.contains(.shift) ? -1 : 1)
                case 51:
                    if field != nil { return event }
                    if !search.query.isEmpty { search.query.removeLast(); searchChanged() }
                default:
                    if field != nil { return event }
                    type(event)
                }
                return nil
            },
            NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
                guard let self, displays.contains(where: { $0.panel === event.window }) else { return event }
                wheel(event)
                return nil
            },
            // A click in another app's window, or outside the displays; one in the grid is its own.
            NSEvent.addGlobalMonitorForEvents(matching: clicks) { [weak self] _ in self?.hide() },
        ].compactMap { $0 }
    }

    private func stopWatching() {
        monitors.forEach { NSEvent.removeMonitor($0) }
        monitors = []
    }
}
