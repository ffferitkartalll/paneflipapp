import CoreGraphics
import Foundation
import PaneFlipCore

/// The live stacks of every zone and the operations on them: snap, select, release, reorder.
/// It is the only place where the persistent memory (`StackMemory`) and real windows are kept in step.
final class StackCoordinator {
    private(set) var stacks: [UUID: ZoneStack] = [:]
    private(set) var visibleZoneIDs: Set<UUID> = []
    /// Windows the user took out of their zone (or a newcomer pushed out): an app's rule must not pull them back.
    /// Kept for the session only.
    private(set) var pulledOut: Set<CGWindowID> = []
    /// The window that had the focus at the last look (see `followFocus`).
    private var lastFocusedID: CGWindowID?
    /// The size a window had before a zone took it in, for giving it back when the user pulls it out.
    private var originalSizes: [CGWindowID: CGSize] = [:]
    /// Called when a stack changed in a way the pill should announce (window added, tab switched).
    var onActivity: ((UUID) -> Void)?
    /// Slides windows when the pill is clicked; without one the chosen window just comes to the front.
    var carousel: ZoneCarousel? {
        didSet { carousel?.onFree = { [weak self] in self?.runWaiting() } }
    }
    var glide: WindowGlide?
    /// With Stage Manager on, the window server decides which windows are shown, and the app does one thing: a dropped
    /// window is sized and placed by its zone. Nothing is held, remembered, stacked or followed, and nothing that was
    /// remembered before is changed.
    var placementOnly: () -> Bool = { false }
    var isSliding: Bool { carousel?.isSliding ?? false }
    /// A screen's layout is being scrolled: its windows follow the fingers, nothing else writes their frames or asks them
    /// anything, and the pills are hidden.
    var isScrolling = false
    /// Called when the focus is on a window of a zone beyond the screen's edge, which is out of sight: the layout should scroll to it.
    var onFocusBeyondTheEdge: ((UUID) -> Void)?

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
    func apply(plan: [UUID: PlannedZone]) {
        visibleZoneIDs = Set(plan.keys)
        for (id, zone) in plan {
            let stack = stacks[id] ?? ZoneStack(id: id)
            stacks[id] = stack
            stack.rect = zone.rect
            stack.frame = zone.frame
            stack.isParked = zone.isParked
            guard !placementOnly(), !isScrolling else { continue }   // a scroll is moving the windows
            for tab in stack.tabs {
                guard let ref = stack.refs[tab.id] else { continue }
                glide?.cancel(ref.id)
                place(ref, at: stack.frame)
            }
        }
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
        unsnap(window: ref.id)
        pulledOut.remove(ref.id)
        // Without stacking a zone holds one app: the newcomer replaces whatever was there.
        if !settings.values.stackingEnabled, let current = stacks[zoneID] {
            for id in Array(current.refs.keys) { unsnap(window: id) }
        }
        let slot = memory.remember(zoneID: zoneID, bundleID: apps.app(pid: ref.pid)?.bundleID ?? "", title: "")
        attach(ref, toSlot: slot, raise: true, glide: true)
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
        windows.setFrame(stack.frame, of: ref)
        if raise { select(ref.id, in: stack) } else { onActivity?(stack.id) }
    }

    /// A pill appeared: the next click will slide.
    func prepareSlides() { carousel?.prepare() }

    /// A click on the pill: the chosen window slides in beside the one in front. Without a carousel, or when there
    /// is nothing to slide past, it simply comes to the front.
    /// `forward` (the new window comes in from the right) is the pill's order unless the caller knows better.
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
        // The pill moves to the new window now, together with the slide, not once the slide is over.
        stack.activeID = id
        onActivity?(stack.id)
        let rect = stack.rect
        carousel.slide(leaving: leaving, entering: entering, in: rect, forward: forward ?? (to > from)) { [windows] in
            windows.setFrame(rect, of: entering)
            windows.raise(entering)
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
        carousel.extend(entering: entering, forward: forward) { [windows] in
            windows.setFrame(rect, of: entering)
            windows.raise(entering)
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
    /// turn of the wheel over its pill does, and not past the first and the last. A window outside any zone, or a zone with one window,
    /// does nothing.
    func cycleFocusedZone(reverse: Bool) {
        guard !placementOnly(), let focused = windows.focusedWindow(), let stack = stack(containing: focused.id), stack.tabs.count > 1 else { return }
        // With nothing moving the window in front is the one in focus; while pictures glide it is the one they go to, and stays.
        if windowScrub == nil, !isSliding, stack.activeID != focused.id { stack.activeID = focused.id }
        stepWindowScrub(in: stack, by: reverse ? -1 : 1)
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
        guard let stack = zoneID(at: point).flatMap({ stacks[$0] }) ?? windows.focusedWindow().flatMap({ stack(containing: $0.id) }) else { return false }
        return beginWindowScrub(in: stack)
    }

    /// The same for a zone that is known (a pill that is scrolled over).
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
        if scrub.ready { carousel?.scrub(to: scrub.gesture.offset) }
    }

    /// A turn of the wheel over a pill: the pictures of the zone's windows go `step` windows on (or back), from the one they are going to
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
        let stack = scrub.stack
        guard let index = scrub.windows.firstIndex(of: scrub.start) else { return carousel?.endScrub(shift: 0) { } ?? () }
        let shift = scrub.forced.map { min(max(index + $0, 0), scrub.windows.count - 1) - index }
            ?? scrub.gesture.shift(zoneWidth: scrub.rect.width, current: index, count: scrub.windows.count)
        guard shift != 0, let entering = stack.refs[scrub.windows[index + shift]] else { return carousel?.endScrub(shift: 0) { } ?? () }
        // The pill moves to the chosen window as the pictures settle.
        stack.activeID = entering.id
        onActivity?(stack.id)
        guard !scrub.failed else { return select(entering.id, in: stack) }
        let rect = scrub.rect
        carousel?.endScrub(shift: shift) { [windows] in
            windows.setFrame(rect, of: entering)
            windows.raise(entering)
        }
    }

    /// A turn of the wheel with the keys held, or a swipe the pictures could not follow: the zone under `point` (else the zone of the window in
    /// focus) goes `step` windows on or back, the way a turn of the wheel over its pill does (`stepWindowScrub(in:by:)`).
    func stepWindowScrub(at point: CGPoint, by step: Int) {
        guard let stack = zoneID(at: point).flatMap({ stacks[$0] }) ?? windows.focusedWindow().flatMap({ stack(containing: $0.id) }) else { return }
        stepWindowScrub(in: stack, by: step)
    }

    private func stepStack(_ stack: ZoneStack, by step: Int) -> Bool {
        guard !placementOnly(), stack.tabs.count > 1, let from = stack.tabs.firstIndex(where: { $0.id == stack.activeID }),
              stack.tabs.indices.contains(from + step) else { return true }
        return slideSelect(stack.tabs[from + step].id, in: stack, forward: step > 0)
    }

    func select(_ id: CGWindowID, in stack: ZoneStack) {
        guard let ref = stack.refs[id] else { return }
        stack.activeID = id
        windows.setFrame(stack.frame, of: ref)
        if !stack.isParked { windows.raise(ref) }
        onActivity?(stack.id)
    }

    /// Makes the pill's selection the window that is really in front in the zone (restored windows are not raised,
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

    /// Takes a window out of its zone for good (the window itself stays open).
    func unsnap(window id: CGWindowID) {
        guard !placementOnly() else { return }
        pulledOut.insert(id)
        memory.forget(window: id)
        removeFromStack(window: id)
    }

    /// The window went away or must wait: leave the zone but keep the memory slot so it can come back.
    func release(window id: CGWindowID) {
        memory.unbind(window: id)
        removeFromStack(window: id)
    }

    /// Removes a window from the live stack only; the memory is the caller's business. Nothing is brought to the
    /// front: the system decides what is revealed, and the pill's selection follows the focus.
    func removeFromStack(window id: CGWindowID) {
        glide?.cancel(id)
        for stack in stacks.values where stack.refs[id] != nil {
            stack.refs[id] = nil
            stack.tabs.removeAll { $0.id == id }
            stack.refreshNames()
            stack.mru.removeAll { $0 == id }
            guard stack.activeID == id else { continue }
            // The pill shows the window that was in front before this one; the window itself is not raised.
            stack.activeID = stack.mru.first { stack.refs[$0] != nil } ?? stack.tabs.last?.id
        }
    }

    /// Placement switched off: let go of every window (the memory stays).
    func releaseAll() {
        for stack in stacks.values { for id in Array(stack.refs.keys) { release(window: id) } }
    }

    /// Stacking switched off: each zone keeps only its front window; the others wait until the zone is free.
    func enforceSingleApp() {
        for stack in stacks.values where stack.tabs.count > 1 {
            let keep = stack.activeID ?? stack.tabs[0].id
            for id in stack.tabs.map(\.id) where id != keep { release(window: id) }
        }
    }

    // MARK: Keeping in step with the system

    /// Picks up title changes of the front tab of each zone: one Accessibility call per zone, not per window, so
    /// a hung app cannot stall the main thread for long. Other tabs catch up when they come to the front.
    func syncTitles() {
        guard !placementOnly() else { return }
        for stack in stacks.values {
            for (i, tab) in stack.tabs.enumerated() where tab.id == stack.activeID {
                guard let ref = stack.refs[tab.id] else { continue }
                let title = windows.title(of: ref) ?? tab.appName
                guard title != tab.title else { continue }
                stack.tabs[i].title = title
                stack.refreshNames()
                memory.updateTitle(ofWindow: tab.id, to: title)
            }
        }
    }

    /// If the user switched to a stacked window some other way (Cmd-Tab, Dock), follow it.
    func followFocus() {
        guard !placementOnly() else { return }
        guard !isSliding else { return }
        let focused = windows.focusedWindow()
        // Only a focus that has just moved there asks for the scroll: a window the user scrolled away from keeps the focus without
        // the layout scrolling back to it.
        let moved = focused?.id != lastFocusedID
        lastFocusedID = focused?.id
        guard let focused, let stack = stack(containing: focused.id) else { return }
        if moved, stack.isParked, !isScrolling { onFocusBeyondTheEdge?(stack.id) }
        guard stack.activeID != focused.id else { return }
        stack.activeID = focused.id
        onActivity?(stack.id)
    }
}
