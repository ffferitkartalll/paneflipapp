import CoreGraphics
import Foundation
import PaneFlipCore

/// The live stacks of every zone and the operations on them: snap, select, release, reorder.
/// It is the only place where the persistent memory (`StackMemory`) and real windows are kept in step.
final class StackCoordinator {
    private(set) var stacks: [UUID: ZoneStack] = [:]
    private(set) var visibleZoneIDs: Set<UUID> = []
    /// The zone of the window that had the focus at the last look (see `followFocus`); nil when that window is in none.
    private(set) var focusedZoneID: UUID?
    /// Windows the user took out of their zone (or a newcomer pushed out): an app's rule must not pull them back.
    /// Kept for the session only.
    private(set) var pulledOut: Set<CGWindowID> = []
    /// Windows of an unplugged display, spread over the usable area of another one: in no zone, their slots wait for the display. Kept for the session only.
    private var displaced: [CGWindowID: (ref: WindowRef, slot: UUID?)] = [:]
    func isDisplaced(_ id: CGWindowID) -> Bool { displaced[id] != nil }
    var displacedWindows: [WindowRef] { displaced.values.map(\.ref) }
    /// The slot a displaced window filled: when its display is back it goes to that slot, not to another one of the same app.
    func displacedSlot(of id: CGWindowID) -> UUID? { displaced[id]?.slot }
    /// The window that had the focus at the last look (see `followFocus`).
    private var lastFocusedID: CGWindowID?
    /// The window that had the focus at the last look, as a handle (see `followFocus`).
    private(set) var lastFocused: WindowRef?

    /// The window in focus as the last look saw it: asking the app that has the focus on the main thread would hold the main thread for as long as the app takes to
    /// answer (a mail client that is busy takes a quarter of a second, the limit). A new look is started at once, off the main thread.
    func focusedWindowCached() -> WindowRef? {
        followFocus()
        return lastFocused
    }
    /// Runs the question "which window has the focus" off the main thread (nil: where it is asked, in tests). The app that has just come to the front
    /// can be slow to answer it (a mail client busy bringing its window up held the whole app for about a second); asked here, the answer would
    /// hold up everything else, the island and the slides included.
    var focusQueue: ((@escaping () -> Void) -> Void)?
    private var askingFocus = false
    private var askAgain = false
    /// The size a window had before a zone took it in, for giving it back when the user pulls it out.
    private var originalSizes: [CGWindowID: CGSize] = [:]
    /// Called when the zone the focus goes to changed by a shortcut or a click, before the window has it: the island lights the zone at once.
    var onFocusMoved: (() -> Void)?
    /// Moves a rectangle from where the system arranges the displays to where they stand on the desk (the moves from one display to the next follow the desk).
    var deskRect: (CGRect) -> CGRect = { $0 }
    /// The display a rectangle belongs to (nil when that is not known): the focus goes on to another display only after the zones of its own, beyond its edge included.
    var displayOf: (CGRect) -> String? = { _ in nil }
    /// Called when a stack changed in a way the island should show (window added, tab switched).
    var onActivity: ((UUID) -> Void)?
    /// The fingers lead the windows of a zone: how far, as a part of the zone's width (0 when they let go). The island's frame follows them.
    var onWindowScrub: ((UUID, CGFloat) -> Void)?
    /// A window of a zone is being stepped to (a shortcut, the wheel): the island shows the zone's windows for a moment.
    var onWindowStep: ((UUID) -> Void)?
    /// Slides windows when a card of the island is clicked; without one the chosen window just comes to the front.
    var carousel: ZoneCarousel? {
        didSet { carousel?.onFree = { [weak self] in
            self?.runWaiting()
            self?.onMotionEnded?()
        } }
    }
    var glide: WindowGlide?
    /// Pictures taken ahead of time: one is dropped when its window goes or its title changes (the content changed).
    var pictures: WindowPictureCache?
    /// A window lost the focus to another one.
    var onFocusLeft: ((CGWindowID) -> Void)?
    /// Something that moved windows may be over (a slide, a swipe, a new layout): the pictures may be taken again after a moment of rest.
    var onMotionEnded: (() -> Void)?
    /// With Stage Manager on, the window server decides which windows are shown, and the app does one thing: a dropped
    /// window is sized and placed by its zone. Nothing is held, remembered, stacked or followed, and nothing that was
    /// remembered before is changed.
    var placementOnly: () -> Bool = { false }
    var isSliding: Bool { carousel?.isSliding ?? false }
    /// Anything of ours is moving other apps' windows (a layout scroll or a zone's windows): periodic jobs that ask or list windows wait.
    var isMoving: Bool { isScrolling || windowScrub != nil || isSliding }
    /// A screen's layout is being scrolled: its windows follow the fingers, nothing else writes their frames or asks them
    /// anything, and the island follows.
    var isScrolling = false
    /// Whether PaneFlip itself has the focus (one of its own windows is in front): the window a swipe ends on is then given the focus.
    var holdsTheFocus: () -> Bool = { false }
    /// Highlights the zone the focus went to (a keyboard shortcut moved it): its rectangle.
    var flashZone: (CGRect) -> Void = { _ in }
    /// Called when the focus moved to a window: the layout scrolls to its zone if it is out of sight beyond the screen's edge, or back to the screen itself
    /// if the zone is one of the screen's own and the layout is scrolled away.
    var onFocusBeyondTheEdge: ((UUID) -> Void)?
    /// A shortcut or a click on the island moved the focus to a zone: the layout should scroll to it (beyond the edge) or back (a zone of the screen itself),
    /// without showing the map of the strip. It tells where the zone will stand when the scroll is over, as the scroll starts. True when a scroll started
    /// or runs: the window comes forward when it is over.
    var onReachBeyondTheEdge: ((UUID, _ standsAt: @escaping (CGRect) -> Void) -> Bool)?

    private let windows: WindowSystem
    private let memory: StackMemory
    private let settings: AppSettings
    private let apps: AppCatalog

    init(windows: WindowSystem, memory: StackMemory, settings: AppSettings, apps: AppCatalog) {
        self.windows = windows
        self.memory = memory
        self.settings = settings
        self.apps = apps
    }

    // MARK: Zones

    /// Makes `zones` (id → rectangle) the visible set, keeping stacks of zones that remain and re-framing their windows.
    func apply(zones: [UUID: CGRect]) {
        apply(plan: zones.mapValues { PlannedZone(rect: $0) })
    }

    /// The same for a plan that may hold zones scrolled out of sight: their windows wait at the display's edge.
    /// Runs a call that writes to an app's windows on the queue of that app, off the main thread (nil: where it is made, in tests).
    var placeQueue: ((pid_t, @escaping () -> Void) -> Void)?

    /// `place`, off the main thread: reading and writing a window waits for its app, and an app that is slow to answer (a mail client takes a quarter of a second for each
    /// call) must not hold the main thread, which every zone change and every focus move would do.
    private func placeLater(_ ref: WindowRef, at frame: CGRect) {
        guard let placeQueue else { return place(ref, at: frame) }
        placeQueue(ref.pid) { [weak self] in self?.place(ref, at: frame) }
    }

    func apply(plan: [UUID: PlannedZone]) {
        visibleZoneIDs = Set(plan.keys)
        for (id, zone) in plan {
            let stack = stacks[id] ?? ZoneStack(id: id)
            stacks[id] = stack
            stack.rect = zone.rect
            stack.isParked = zone.isParked
            stack.number = zone.number
            stack.order = zone.order
            stack.frame = zone.frame
            guard !placementOnly(), !isScrolling else { continue }   // a scroll is moving the windows
            for tab in stack.tabs {
                guard let ref = stack.refs[tab.id] else { continue }
                glide?.cancel(ref.id)
                placeLater(ref, at: stack.frame)
            }
        }
        onMotionEnded?()
    }

    /// Puts a window at a frame, writing only what differs: a window already there is left alone (an app redraws, and
    /// flashes, when it is written to), one of the right size is only moved.
    private func place(_ ref: WindowRef, at frame: CGRect) {
        guard let now = windows.frame(of: ref) else { return windows.setFrame(frame, of: ref) }
        func near(_ a: CGFloat, _ b: CGFloat) -> Bool { abs(a - b) < 1.5 }
        let sameSize = near(now.width, frame.width) && near(now.height, frame.height)
        if sameSize && near(now.minX, frame.minX) && near(now.minY, frame.minY) { return }
        if sameSize { windows.setPosition(frame.origin, of: ref) } else { windows.setFrame(frame, of: ref) }
    }

    /// The zones in view (not the ones scrolled away).
    var visibleStacks: [ZoneStack] { visibleZoneIDs.compactMap { stacks[$0] }.filter { !$0.isParked } }

    func zoneID(at point: CGPoint) -> UUID? {
        // The widened rectangles of neighbours overlap, so exact containment must win; the Set order is random.
        let stacks = visibleStacks
        return (stacks.first { $0.rect.contains(point) } ?? stacks.first { $0.rect.insetBy(dx: -4, dy: -4).contains(point) })?.id
    }

    func prune(keeping alive: Set<UUID>) {
        stacks = stacks.filter { alive.contains($0.key) }
    }

    func stack(containing windowID: CGWindowID) -> ZoneStack? {
        stacks.values.first { $0.refs[windowID] != nil }
    }

    /// Every window currently held by a stack.
    var heldWindows: [WindowRef] { stacks.values.flatMap { Array($0.refs.values) } }

    // MARK: Membership

    /// Snaps a window into a zone and remembers it there.
    func snap(_ ref: WindowRef, into zoneID: UUID) {
        guard settings.values.placementEnabled, let zone = stacks[zoneID], !isIgnored(ref) else { return }
        guard !placementOnly() else {
            if let glide { glide.glide(ref, to: zone.rect) } else { windows.setFrame(zone.rect, of: ref) }
            return
        }
        let home = memory.home(ofWindow: ref.id)
        unsnap(window: ref.id)
        pulledOut.remove(ref.id)
        displaced[ref.id] = nil
        let slot = memory.remember(zoneID: zoneID, bundleID: apps.app(pid: ref.pid)?.bundleID ?? "", title: "")
        memory.setHome(slot: slot, to: home)
        // A zone beyond the screen's edge keeps its windows out of sight: the window is put there without being brought forward.
        attach(ref, toSlot: slot, raise: !zone.isParked, glide: true)
    }

    /// Whether the window belongs to an app the user asked PaneFlip to leave alone.
    func isIgnored(_ ref: WindowRef) -> Bool {
        apps.app(pid: ref.pid).map { settings.values.ignoredApps.contains($0.bundleID) } ?? false
    }

    /// An app was added to the ignored apps: its windows leave their zones where they stand. The slots stay, so the apps
    /// return to their zones if they are taken off the list.
    func releaseIgnoredApps() {
        let ignored = Set(settings.values.ignoredApps)
        for stack in stacks.values {
            for tab in stack.tabs where ignored.contains(tab.bundleID) { release(window: tab.id) }
        }
    }

    /// Puts a live window into the zone its memory slot names, at the position the user arranged.
    /// With `glide` the window travels to the zone instead of jumping there (a window the user just dropped).
    func attach(_ ref: WindowRef, toSlot slot: Int, raise: Bool, glide: Bool = false) {
        guard memory.records.indices.contains(slot), let stack = stacks[memory.records[slot].zoneID] else { return }
        if originalSizes[ref.id] == nil, let size = windows.frame(of: ref)?.size { originalSizes[ref.id] = size }
        let appName = apps.app(pid: ref.pid)?.name ?? "?"
        let bundleID = apps.app(pid: ref.pid)?.bundleID ?? ""
        let title = windows.title(of: ref) ?? appName
        memory.bind(slot: slot, toWindow: ref.id, title: title)
        stack.refs[ref.id] = ref
        let position = stack.tabs.filter { (memory.index(ofWindow: $0.id) ?? Int.max) < slot }.count
        stack.tabs.insert(.init(id: ref.id, title: title, appName: appName, bundleID: bundleID, icon: apps.icon(pid: ref.pid)), at: position)
        stack.refreshNames()
        if stack.activeID == nil { stack.activeID = ref.id }
        if glide, raise, !stack.isParked, let mover = self.glide {
            stack.activeID = ref.id
            windows.raise(ref)
            mover.glide(ref, to: stack.rect)
            onActivity?(stack.id)
            return
        }
        placeLater(ref, at: stack.frame)
        if raise { select(ref.id, in: stack) } else { onActivity?(stack.id) }
    }

    /// The island opened: the next click on a card will slide.
    func prepareSlides() { carousel?.prepare() }

    /// A click on a card of the island: the chosen window slides in beside the one in front. Without a carousel, or when there
    /// is nothing to slide past, it simply comes to the front.
    /// `forward` (the new window comes in from the right) is the order of the cards unless the caller knows better.
    /// False when a slide runs that cannot take the choice on yet (it goes the other way, or a picture for it is being taken): nothing
    /// has happened then.
    @discardableResult
    func slideSelect(_ id: CGWindowID, in stack: ZoneStack, forward: Bool? = nil) -> Bool {
        if isSliding { return extendSlide(to: id, in: stack, forward: forward) }
        guard let carousel, let entering = stack.refs[id], let frontID = stack.activeID, frontID != id,
              let leaving = stack.refs[frontID],
              let from = stack.tabs.firstIndex(where: { $0.id == frontID }), let to = stack.tabs.firstIndex(where: { $0.id == id })
        else {
            select(id, in: stack)
            return true
        }
        // The island moves to the new window now, together with the slide, not once the slide is over.
        stack.activeID = id
        onActivity?(stack.id)
        let rect = stack.rect
        let zone = stack.tabs.map(\.id), generation = nextSwap()
        carousel.slide(leaving: leaving, entering: entering, in: rect, forward: forward ?? (to > from)) { [self] in
            bringForward(entering, among: zone, generation: generation)
        }
        return true
    }

    /// A choice while a slide runs: if it goes the same way in the same zone, the slide is carried on to the new window (the
    /// pictures of the windows it passed are there already). False when it cannot be yet: nothing has happened then.
    private func extendSlide(to id: CGWindowID, in stack: ZoneStack, forward: Bool?) -> Bool {
        guard let carousel, let entering = stack.refs[id], let frontID = stack.activeID, frontID != id,
              let from = stack.tabs.firstIndex(where: { $0.id == frontID }), let to = stack.tabs.firstIndex(where: { $0.id == id })
        else { return true }
        let forward = forward ?? (to > from)
        let rect = stack.rect
        guard carousel.canExtend(forward: forward, in: rect) else { return false }
        stack.activeID = id
        onActivity?(stack.id)
        let zone = stack.tabs.map(\.id), generation = nextSwap()
        carousel.extend(entering: entering, forward: forward) { [self] in
            bringForward(entering, among: zone, generation: generation)
        }
        return true
    }

    // MARK: Choices that wait

    /// Choices made with the keys or the wheel while a slide runs that cannot take them on (the other way, or while a picture for the
    /// carrying on is taken). They are not lost: each is tried again, in turn, when the slide can take it. A few at most, so that a key held
    /// down does not go on after it is let go.
    private var waiting: [() -> Bool] = []
    private static let mostWaiting = 3

    /// Does `attempt` now, or lets it wait. An attempt returns false when it has to wait.
    private func doOrWait(_ attempt: @escaping () -> Bool) {
        if waiting.isEmpty, attempt() { return }
        if waiting.count < Self.mostWaiting { waiting.append(attempt) }
    }

    private func runWaiting() {
        while !waiting.isEmpty {
            // Taken out first: trying it can call this again (a picture that is there at once), and must not find it still in the list.
            let first = waiting.removeFirst()
            guard first() else {
                waiting.insert(first, at: 0)
                return
            }
        }
    }

    /// Control+Option+Right/Left: the zone of the window in focus moves on to its next window (the previous one when `reverse`), the way a
    /// turn of the wheel over its row of cards does, and not past the first and the last. A window outside any zone, or a zone with one window,
    /// does nothing.
    func cycleFocusedZone(reverse: Bool) {
        guard !placementOnly(), let focused = focusedWindowCached(), let stack = stack(containing: focused.id), stack.tabs.count > 1 else { return }
        // With nothing moving the window in front is the one in focus; while pictures glide it is the one they go to, and stays.
        if windowScrub == nil, !isSliding, stack.activeID != focused.id { stack.activeID = focused.id }
        stepWindowScrub(in: stack, by: reverse ? -1 : 1)
    }

    /// A click on a zone of the island: the focus goes to the front window of that zone, unless the focus is in the zone already (or it
    /// has no window). A zone beyond the screen's edge is scrolled into view first. At once, with no frame sliding over from the zone that had the focus, as it does for the shortcuts.
    func focus(zone id: UUID) {
        guard !placementOnly(), windowScrub == nil, !isSliding, focusedZoneID != id,
              let target = stacks[id], let active = target.activeID, let ref = target.refs[active] else { return }
        // The highlight goes at once, and the app is asked off the main thread: an app that is slow to answer (a mail client busy bringing its window up)
        // must neither keep the highlight waiting nor hold the whole app. What is read back from it is not believed until it has caught up (2 s at most).
        chosenFocus = (id, ref.id, Date().addingTimeInterval(4))
        focusedZoneID = id
        onFocusMoved?()
        // Beyond the screen's edge, or on the screen with the layout scrolled away: as for the shortcuts, the layout scrolls and the window comes forward once
        // it stands there (flashed: a click on the island shows no frame, as for a zone that is in view).
        if onReachBeyondTheEdge?(id, { _ in }) == true || target.isParked {
            focusPending = (id, ref, Date().addingTimeInterval(4), true)
            return
        }
        chosenFocus?.until = Date().addingTimeInterval(2)
        if let focusQueue { focusQueue { [windows] in windows.raise(ref) } } else { windows.raise(ref) }
    }

    /// The window and zone a click on the island chose, until the focus has been seen there.
    private var chosenFocus: (zone: UUID, window: CGWindowID, until: Date)?

    /// Control+Option+O/K/L/;: the focus goes to the front window of the zone beside the zone of the window in focus (the zone of the window
    /// under the pointer when that one is in none). Past the last zone on the screen to the left or to the right it goes on to the zones
    /// beyond the screen's edge, which the layout scrolls into view. Nothing happens where there is no such zone.
    ///
    /// A press only moves the place the focus is going to (`chosenFocus`) and asks the layout to bring that zone into view; the window comes forward
    /// once the zone is in view and nothing scrolls. Presses that follow quickly, with scrolls and landings in between, start from the place the
    /// last one went to and end on the last one: they do not depend on the app having caught up, nor on where the scroll is.
    func focusZone(toward direction: ZoneDirection) {
        guard settings.values.zoneNavigationEnabled, !placementOnly(), windowScrub == nil, !isSliding else { return }
        let from = chosenFocus.flatMap { $0.until > Date() ? stacks[$0.zone] : nil } ?? focusedZoneID.flatMap { stacks[$0] }
            ?? focusedWindowCached().flatMap { stack(containing: $0.id) }
        if let from { return moveFocus(from: from, toward: direction) }
        // The window in focus is in no zone: the zone of the window under the pointer is the start. The app is asked off the main thread.
        guard let focusQueue else {
            guard let hit = windows.windowUnderPointer(), let stack = stack(containing: hit.ref.id) else { return }
            return moveFocus(from: stack, toward: direction)
        }
        focusQueue { [self] in
            let hit = windows.windowUnderPointer()
            DispatchQueue.main.async { [self] in
                if let hit, let stack = stack(containing: hit.ref.id) { moveFocus(from: stack, toward: direction) }
            }
        }
    }

    private func moveFocus(from current: ZoneStack, toward direction: ZoneDirection) {
        let horizontal = direction == .left || direction == .right
        let wide = horizontal && settings.values.zoneNavigationBeyondEdges && settings.values.overflowZonesEnabled
        func candidate(_ stack: ZoneStack) -> (id: UUID, rect: CGRect, number: Int, display: String?) { (stack.id, deskRect(stack.rect), stack.order, displayOf(stack.rect)) }
        let visible = visibleStacks.filter { $0.id != current.id && !$0.isEmpty }.map(candidate)
        let beyond = wide ? stacks.values.filter { $0.isParked && !$0.isEmpty && $0.id != current.id }.map(candidate) : []
        let currentRect = deskRect(current.rect)
        let display = displayOf(current.rect)
        func nearest(_ zones: [(id: UUID, rect: CGRect, number: Int, display: String?)]) -> UUID? {
            ZoneNeighbour.nearest(to: currentRect, number: current.order, among: zones.map { (id: $0.id, rect: $0.rect, number: $0.number) }, toward: direction)
        }
        let own = { (zone: (id: UUID, rect: CGRect, number: Int, display: String?)) in zone.display == display }
        let next: UUID?
        if current.isParked {
            // From a zone out of sight the nearest of all of its display, not the first one on the screen: the zones between are not skipped.
            next = wide ? nearest((visible + beyond).filter(own)) ?? nearest(visible.filter { !own($0) }) : nil
        } else {
            // On the screen first; none that way: the nearest zone with windows beyond the edge, the one next to the screen first; none there either: the
            // zones of another display.
            next = nearest(visible.filter(own)) ?? nearest(beyond.filter(own)) ?? nearest(visible.filter { !own($0) })
        }
        guard let id = next, let target = stacks[id], let active = target.activeID, let ref = target.refs[active] else { return }
        chosenFocus = (id, ref.id, Date().addingTimeInterval(4))
        focusedZoneID = id
        onFocusMoved?()
        focusPending = (id, ref, Date().addingTimeInterval(4), false)
        // Out of sight, scrolled away from the screen's own zones, or a scroll runs that may take it out of sight: the layout is asked to bring it into view (a
        // scroll that runs is given a new aim), and the window comes forward and the frame shows when that is over (`finishFocusBeyondTheEdge`), so that nothing
        // keeps the machine busy while the pictures glide. The frame shows at once where the zone will stand when the layout can say so.
        let scrolls = onReachBeyondTheEdge?(id) { [weak self] rect in
            self?.focusPending?.flashed = true
            self?.flashZone(rect)
        } ?? false
        if !scrolls, !target.isParked, !isScrolling {
            // In view and nothing moves: the frame first, which the render server fades by itself; bringing the window forward may keep this
            // thread busy a while.
            focusPending = nil
            flashZone(target.rect)
            if let focusQueue { focusQueue { [windows] in windows.raise(ref) } } else { windows.raise(ref) }   // in order, off the main thread
        }
    }

    /// A zone beyond the edge that a shortcut asked for, and the window to bring forward in it once it is in view.
    private var focusPending: (zone: UUID, ref: WindowRef, until: Date, flashed: Bool)?

    /// The glide has come to its end and the zones stand where they will: the frame shows now, not when the windows are all in place.
    func showFocusFrame(in plan: [UUID: PlannedZone]) {
        guard var pending = focusPending, !pending.flashed, pending.until > Date(), let zone = plan[pending.zone], !zone.isParked else { return }   // when no frame went ahead
        pending.flashed = true
        focusPending = pending
        flashZone(zone.rect)
    }

    /// A window was sent to a zone: the layout scrolls so that the zone is in view, as it does when the focus goes to a window there (to a zone beyond the screen's edge;
    /// from beyond the edge to a zone of the screen itself, back, so that no zone beyond the edge is in view), and the window comes forward when the scroll is over,
    /// without the frame that marks a zone the focus went to. Nothing happens where no scroll is needed.
    func revealSent(_ ref: WindowRef, in zoneID: UUID) {
        guard stacks[zoneID] != nil, onReachBeyondTheEdge?(zoneID, { _ in }) == true else { return }
        chosenFocus = (zoneID, ref.id, Date().addingTimeInterval(4))
        focusedZoneID = zoneID
        onFocusMoved?()
        // It counts as flashed from the start: the zone already shows where the window went.
        focusPending = (zoneID, ref, Date().addingTimeInterval(4), true)
    }

    /// The scroll is over: if the zone the shortcut asked for is in view now, its window comes forward and its frame shows.
    func finishFocusBeyondTheEdge() {
        guard let pending = focusPending else { return }
        guard pending.until > Date() else { return focusPending = nil }
        guard let stack = stacks[pending.zone], !stack.isParked else { return }   // a scroll that follows brings it in
        focusPending = nil
        if !pending.flashed { flashZone(stack.rect) }
        if let focusQueue { focusQueue { [windows] in windows.raise(pending.ref) } } else { windows.raise(pending.ref) }
    }

    // MARK: A swipe the fingers lead

    /// One swipe through a zone's windows with two fingers: the pictures of the windows follow the fingers, over as many windows as
    /// they go, and the swipe lets go on one of them when the fingers lift.
    private final class WindowScrub {
        let stack: ZoneStack
        let rect: CGRect
        /// A wheel, not fingers, moves it: it lets go this many windows from the one in front, whatever the swipe did.
        var forced: Int?
        /// The windows the swipe passes, in order: those that have a picture (all of them until the pictures are there).
        var windows: [CGWindowID]
        let start: CGWindowID
        var gesture = ScrubGesture()
        /// The pictures are on the stage and follow the fingers.
        var ready = false
        /// There are no pictures (motion is reduced, or the capture failed): the window just comes forward at the end.
        var failed = false
        var ended = false

        init(stack: ZoneStack, start: CGWindowID, rect: CGRect) {
            self.stack = stack
            self.start = start
            self.rect = rect
            windows = stack.tabs.map(\.id)
        }
    }
    private var windowScrub: WindowScrub?

    /// Two fingers came down over `point`: the zone under it (else the zone of the window in focus) is the one to swipe through. False
    /// when the pictures cannot follow the fingers (a slide that is not a swipe runs, there is nothing to swipe through): the caller steps
    /// instead, and a step that has to wait for the slide waits.
    @discardableResult
    func beginWindowScrub(at point: CGPoint) -> Bool {
        guard let stack = zoneID(at: point).flatMap({ stacks[$0] }) ?? focusedWindowCached().flatMap({ stack(containing: $0.id) }) else { return false }
        return beginWindowScrub(in: stack)
    }

    /// The same for a zone that is known (the row of cards that is scrolled over).
    @discardableResult
    func beginWindowScrub(in stack: ZoneStack) -> Bool {
        guard windowScrub == nil, !placementOnly(), !isSliding || carousel?.isSettlingSwipe == true,
              stack.tabs.count > 1, let start = stack.activeID else { return false }
        let scrub = WindowScrub(stack: stack, start: start, rect: stack.rect)
        windowScrub = scrub
        // A swipe whose end never comes (a lost event) must not hold the windows for good.
        DispatchQueue.main.asyncAfter(deadline: .now() + 15) { [weak self] in
            if self?.windowScrub === scrub { self?.endWindowScrub() }
        }
        guard let carousel else { scrub.failed = true; return true }
        carousel.beginScrub(windows: stack.tabs.compactMap { stack.refs[$0.id] }, current: start, in: scrub.rect) { [weak self] shown, carried in
            guard let self, windowScrub === scrub else { return }
            if let shown {
                scrub.windows = shown
                scrub.gesture.limit(to: ScrubGesture.range(zoneWidth: scrub.rect.width, current: shown.firstIndex(of: start) ?? 0, count: shown.count))
                if let carried { scrub.gesture.resume(at: carried) }   // fingers that took over a gliding swipe go on from where its pictures are
                scrub.ready = true
                carousel.scrub(to: scrub.gesture.offset)
                onWindowScrub?(stack.id, scrub.gesture.offset / scrub.rect.width)
            } else {
                scrub.failed = true
            }
            if scrub.ended { finishWindowScrub(scrub) }
        }
        return true
    }

    /// The fingers moved by `delta` points (to the right is positive: the content follows them).
    func moveWindowScrub(by delta: CGFloat, at time: TimeInterval) {
        guard let scrub = windowScrub, !scrub.ended else { return }
        scrub.gesture.add(delta, at: time)
        if scrub.ready {
            carousel?.scrub(to: scrub.gesture.offset)
            onWindowScrub?(scrub.stack.id, scrub.gesture.offset / scrub.rect.width)
        }
    }

    /// A turn of the wheel over the row of cards: the pictures of the zone's windows go `step` windows on (or back), from the one they are going to
    /// if they are already on their way, so that turns follow one another as quickly as they come, in either direction. Without
    /// pictures to move (a slide that is not a swipe runs, motion is reduced) it is a step like those of the keys.
    func stepWindowScrub(in stack: ZoneStack, by step: Int) {
        guard step != 0 else { return }
        if let scrub = windowScrub {
            // Turns that come while the pictures of an earlier one are still being taken add up to it.
            if scrub.stack === stack, scrub.ended, let forced = scrub.forced { scrub.forced = forced + step }
            return
        }
        // Not past the first and the last window: there is nothing to move to, and nothing is photographed for it.
        guard !placementOnly(), let from = stack.tabs.firstIndex(where: { $0.id == stack.activeID }), stack.tabs.indices.contains(from + step) else { return }
        onWindowStep?(stack.id)
        guard beginWindowScrub(in: stack) else {
            doOrWait { [weak self, weak stack] in stack.map { self?.stepStack($0, by: step) ?? true } ?? true }
            return
        }
        windowScrub?.forced = step
        endWindowScrub()
    }

    /// The fingers lifted.
    func endWindowScrub() {
        guard let scrub = windowScrub, !scrub.ended else { return }
        scrub.ended = true
        if scrub.ready || scrub.failed { finishWindowScrub(scrub) }   // else it waits for the pictures
    }

    private func finishWindowScrub(_ scrub: WindowScrub) {
        windowScrub = nil
        defer { onMotionEnded?() }
        let stack = scrub.stack
        onWindowScrub?(stack.id, 0)
        guard let index = scrub.windows.firstIndex(of: scrub.start) else { return carousel?.endScrub(shift: 0) { } ?? () }
        let shift = scrub.forced.map { min(max(index + $0, 0), scrub.windows.count - 1) - index }
            ?? scrub.gesture.shift(zoneWidth: scrub.rect.width, current: index, count: scrub.windows.count)
        guard shift != 0, let entering = stack.refs[scrub.windows[index + shift]] else {
            // Back on the window it began on: a swipe that took the focus gives it to this window.
            let staying = stack.refs[scrub.start]
            return carousel?.endScrub(shift: 0) { [windows, weak self] in if self?.holdsTheFocus() == true, let staying { windows.raise(staying) } } ?? ()
        }
        // The island moves to the chosen window as the pictures settle.
        stack.activeID = entering.id
        onActivity?(stack.id)
        guard !scrub.failed else { return select(entering.id, in: stack) }
        let zone = stack.tabs.map(\.id), generation = nextSwap()
        carousel?.endScrub(shift: shift) { [self] in
            bringForward(entering, among: zone, generation: generation)
        }
    }

    /// A click on a card: the zone goes to that window the way a turn of the wheel goes (as many windows on or back as lie between), so a click
    /// while the pictures still glide takes them over where they are, in either direction, and waits for nothing.
    func clickSelect(_ id: CGWindowID, in stack: ZoneStack) {
        guard let from = stack.tabs.firstIndex(where: { $0.id == stack.activeID }), let to = stack.tabs.firstIndex(where: { $0.id == id }) else { return }
        stepWindowScrub(in: stack, by: to - from)
    }

    /// A turn of the wheel with the keys held, or a swipe the pictures could not follow: the zone under `point` (else the zone of the window in
    /// focus) goes `step` windows on or back, the way a turn of the wheel over its row of cards does (`stepWindowScrub(in:by:)`).
    func stepWindowScrub(at point: CGPoint, by step: Int) {
        guard let stack = zoneID(at: point).flatMap({ stacks[$0] }) ?? focusedWindowCached().flatMap({ stack(containing: $0.id) }) else { return }
        stepWindowScrub(in: stack, by: step)
    }

    private func stepStack(_ stack: ZoneStack, by step: Int) -> Bool {
        guard !placementOnly(), stack.tabs.count > 1, let from = stack.tabs.firstIndex(where: { $0.id == stack.activeID }),
              stack.tabs.indices.contains(from + step) else { return true }
        return slideSelect(stack.tabs[from + step].id, in: stack, forward: step > 0)
    }

    private let swapLock = NSLock()
    private var swapCount = 0

    /// Counts the swaps asked for (on the main thread, when the slide is asked for): a swap that waits is given up when a later one has been asked for.
    private func nextSwap() -> Int {
        swapLock.lock()
        defer { swapLock.unlock() }
        swapCount += 1
        return swapCount
    }

    private func isLatestSwap(_ generation: Int) -> Bool {
        swapLock.lock()
        defer { swapLock.unlock() }
        return swapCount == generation
    }

    /// What a slide's `swap` does, off the main thread: the window is brought forward, and this waits until the system lists
    /// it in front of the other windows of its zone (`among`), a moment at most, or until a later choice has been made (then this window is not to be in front any more).
    /// The pictures give way to the real window only then: an app that is slow to bring a window forward (a mail client) would otherwise show the window that was in
    /// front for a moment, between the end of the slide and the arrival of the next.
    private func bringForward(_ ref: WindowRef, among zone: [CGWindowID], generation: Int) {
        // The window stands in its zone already (the zones are put right at every refresh, `apply(plan:)`): reading its place would only wait for its app.
        windows.raise(ref)
        let ids = Set(zone)
        let giveUp = CFAbsoluteTimeGetCurrent() + 0.6
        while CFAbsoluteTimeGetCurrent() < giveUp {
            if windows.windowIDsFrontToBack().first(where: { ids.contains($0) }) == ref.id { return }
            guard isLatestSwap(generation) else { return }
            Thread.sleep(forTimeInterval: 0.012)
        }
    }

    func select(_ id: CGWindowID, in stack: ZoneStack) {
        guard let ref = stack.refs[id] else { return }
        stack.activeID = id
        placeLater(ref, at: stack.frame)   // a window already there is not written to: an app that answers slowly would hold everything up
        if !stack.isParked { windows.raise(ref) }
        onActivity?(stack.id)
    }

    /// Makes the island's front card the window that is really in front in the zone (restored windows are not raised,
    /// so the first one attached must not count as the active one).
    func followFrontmost(in stack: ZoneStack) {
        guard let front = windows.windowIDsFrontToBack().first(where: { stack.refs[$0] != nil }), stack.activeID != front else { return }
        stack.activeID = front
        onActivity?(stack.id)
    }

    /// The user dragged a window out of its zone: it leaves the stack and, when the setting asks for it, glides back to the size it
    /// had before the zone took it in, kept under the pointer the way it was held (the title bar stays where it is).
    func takeOut(_ ref: WindowRef, grabbedAt pointer: CGPoint) {
        let size = originalSizes.removeValue(forKey: ref.id)
        let wasHeld = stack(containing: ref.id) != nil
        let frame = windows.frame(of: ref)
        unsnap(window: ref.id)   // lets go of the glide that brought the window in, so this comes after it
        guard settings.values.restoreSizeOnLeave, wasHeld, let size, let frame else { return }
        let share = frame.width > 0 ? min(max((pointer.x - frame.minX) / frame.width, 0), 1) : 0
        let target = CGRect(x: pointer.x - share * size.width, y: frame.minY, width: size.width, height: size.height)
        if let glide { glide.glide(ref, to: target) } else { windows.setFrame(target, of: ref) }
    }

    /// A window is taken out of its zone by a key: it goes to the middle of `area`, the usable area of its screen, at the size it had before the zone took
    /// it in when the setting asks for it, else at the size it has (never larger than the area).
    func remove(_ ref: WindowRef, centredIn area: CGRect) {
        let before = originalSizes.removeValue(forKey: ref.id)
        let current = windows.frame(of: ref)?.size
        unsnap(window: ref.id)
        let size = (settings.values.restoreSizeOnLeave ? before : nil) ?? current ?? area.size
        let fitted = CGSize(width: min(size.width, area.width), height: min(size.height, area.height))
        let target = CGRect(x: area.midX - fitted.width / 2, y: area.midY - fitted.height / 2, width: fitted.width, height: fitted.height)
        if let glide { glide.glide(ref, to: target) } else { windows.setFrame(target, of: ref) }
    }

    /// Takes a window out of its zone for good (the window itself stays open).
    func unsnap(window id: CGWindowID) {
        guard !placementOnly() else { return }
        pulledOut.insert(id)
        memory.forget(window: id)
        removeFromStack(window: id)
    }

    /// Why the last window of an app left its zone, for the card that stands for the app in the island.
    private(set) var absences: [String: WindowAbsence] = [:]

    private func app(of ref: WindowRef) -> String? { apps.app(pid: ref.pid)?.bundleID }

    /// A slot of a zone was put in the place of another one (a card of the island was dragged): the windows of the zone stand in the new order.
    func moveSlot(_ i: Int, toPlaceOf j: Int, inZone zone: UUID) {
        memory.moveSlot(i, toPlaceOf: j)
        guard let stack = stacks[zone] else { return }
        let place = { (tab: ZoneStack.Tab) in self.memory.index(ofWindow: tab.id) ?? Int.max }
        stack.tabs = stack.tabs.enumerated().sorted { (place($0.element), $0.offset) < (place($1.element), $1.offset) }.map(\.element)
        stack.refreshNames()
    }

    /// The window went away or must wait: leave the zone but keep the memory slot so it can come back.
    func release(window id: CGWindowID) {
        if let ref = stacks.values.lazy.compactMap({ $0.refs[id] }).first, let bundleID = app(of: ref) {
            absences[bundleID] = apps.isHidden(pid: ref.pid) ? .hidden : (windows.isMinimized(ref) ? .minimized : .closed)
        }
        memory.unbind(window: id)
        removeFromStack(window: id)
    }

    /// The display of `zones` was unplugged: their windows leave the zones and spread over `area`, the usable area of another display. Their slots
    /// stay bound to them and remember the zone (see `StackMemory.displace`).
    func displace(zones: Set<UUID>, over area: CGRect) {
        memory.displace(zones: zones)
        for id in zones {
            guard let stack = stacks[id] else { continue }
            for ref in Array(stack.refs.values) {
                displaced[ref.id] = (ref, memory.index(ofWindow: ref.id).map { memory.records[$0].id })
                removeFromStack(window: ref.id)
                windows.setFrame(area, of: ref)
            }
        }
    }

    /// The window has its zone again (or is gone): it is no longer displaced.
    func settled(_ id: CGWindowID) { displaced[id] = nil }

    /// Removes a window from the live stack only; the memory is the caller's business. Nothing is brought to the
    /// front: the system decides what is revealed, and the island's front card follows the focus.
    func removeFromStack(window id: CGWindowID) {
        glide?.cancel(id)
        pictures?.forget(id)
        for stack in stacks.values where stack.refs[id] != nil {
            stack.refs[id] = nil
            stack.tabs.removeAll { $0.id == id }
            stack.refreshNames()
            stack.mru.removeAll { $0 == id }
            guard stack.activeID == id else { continue }
            // The island shows the window that was in front before this one; the window itself is not raised.
            stack.activeID = stack.mru.first { stack.refs[$0] != nil } ?? stack.tabs.last?.id
        }
    }

    /// Placement switched off: let go of every window (the memory stays).
    func releaseAll() {
        for stack in stacks.values { for id in Array(stack.refs.keys) { release(window: id) } }
    }

    // MARK: Keeping in step with the system

    /// Picks up title changes of the front tab of each zone: one Accessibility call per zone, not per window, so
    /// a hung app cannot stall the main thread for long. Other tabs catch up when they come to the front.
    func syncTitles() {
        guard !placementOnly() else { return }
        let now = ProcessInfo.processInfo.systemUptime
        // A window whose app was slow to give its title is left alone for a few seconds: asking every half second keeps an app busy that has no time for it.
        let asked = stacks.values.compactMap { stack in stack.activeID.flatMap { id in stack.refs[id].map { (stack: stack, id: id, ref: $0) } } }
            .filter { slowTitles[$0.id].map { now >= $0 } ?? true }
        guard let focusQueue else { return apply(titles: asked.map { ($0.stack, $0.id, windows.title(of: $0.ref)) }) }
        // Off the main thread, one round at a time: an app that is slow to answer must not hold the app.
        guard !askingTitles else { return }
        askingTitles = true
        focusQueue { [self] in
            var slow: [CGWindowID] = []
            let titles = asked.map { item -> (ZoneStack, CGWindowID, String?) in
                let began = CFAbsoluteTimeGetCurrent()
                let title = windows.title(of: item.ref)
                if CFAbsoluteTimeGetCurrent() - began > 0.1 { slow.append(item.id) }
                return (item.stack, item.id, title)
            }
            DispatchQueue.main.async { [self] in
                askingTitles = false
                slow.forEach { slowTitles[$0] = ProcessInfo.processInfo.systemUptime + 5 }
                if !placementOnly() { apply(titles: titles) }
            }
        }
    }

    private var askingTitles = false
    private var slowTitles: [CGWindowID: TimeInterval] = [:]

    private func apply(titles: [(ZoneStack, CGWindowID, String?)]) {
        for (stack, id, answer) in titles {
            guard stack.activeID == id, let i = stack.tabs.firstIndex(where: { $0.id == id }) else { continue }   // it came and went meanwhile
            let tab = stack.tabs[i], title = answer ?? tab.appName
            guard title != tab.title else { continue }
            stack.tabs[i].title = title
            pictures?.forget(tab.id)
            stack.refreshNames()
            memory.updateTitle(ofWindow: tab.id, to: title)
        }
    }

    /// If the user switched to a stacked window some other way (Cmd-Tab, Dock), follow it.
    func followFocus() {
        guard !placementOnly() else { return }
        guard !isSliding else { return }
        guard let focusQueue else { return follow(windows.focusedWindow()) }
        // One question at a time; one that is asked meanwhile is asked once more when the answer to this one is in.
        if askingFocus { askAgain = true; return }
        askingFocus = true
        focusQueue { [self] in
            let focused = windows.focusedWindow()
            DispatchQueue.main.async { [self] in
                askingFocus = false
                if !placementOnly(), !isSliding { follow(focused) }
                if askAgain { askAgain = false; followFocus() }
            }
        }
    }

    private func follow(_ focused: WindowRef?) {
        // A zone a shortcut brings into view counts as focused from the moment the layout starts to scroll to it.
        if let chosen = chosenFocus, chosen.until < Date() || focused?.id == chosen.window { chosenFocus = nil }
        focusedZoneID = focusPending.flatMap { $0.flashed && $0.until > Date() ? $0.zone : nil } ?? chosenFocus?.zone ?? focused.flatMap { stack(containing: $0.id)?.id }
        // Only a focus that has just moved there asks for the scroll: a window the user scrolled away from keeps the focus without
        // the layout scrolling back to it.
        let moved = focused?.id != lastFocusedID
        let previous = lastFocusedID
        lastFocusedID = focused?.id
        lastFocused = focused
        if moved, let previous { onFocusLeft?(previous) }
        guard let focused, let stack = stack(containing: focused.id) else { return }
        if moved, !isScrolling { onFocusBeyondTheEdge?(stack.id) }
        guard stack.activeID != focused.id else { return }
        stack.activeID = focused.id
        onActivity?(stack.id)
    }
}

