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
    /// Called when a stack changed in a way the pill should announce (window added, tab switched).
    var onActivity: ((UUID) -> Void)?
    /// Slides windows when the pill is clicked; without one the chosen window just comes to the front.
    var carousel: ZoneCarousel?
    var glide: WindowGlide?
    /// With Stage Manager on, the window server decides which windows are shown, and the app does one thing: a dropped
    /// window is sized and placed by its zone. Nothing is held, remembered, stacked or followed, and nothing that was
    /// remembered before is changed.
    var placementOnly: () -> Bool = { false }
    var isSliding: Bool { carousel?.isSliding ?? false }
    /// A screen's layout is being scrolled: its windows follow the fingers, nothing else writes their frames or asks them
    /// anything, and the pills are hidden.
    var isScrolling = false

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
        guard settings.values.placementEnabled, let zone = stacks[zoneID] else { return }
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

    /// Puts a live window into the zone its memory slot names, at the position the user arranged.
    /// With `glide` the window travels to the zone instead of jumping there (a window the user just dropped).
    func attach(_ ref: WindowRef, toSlot slot: Int, raise: Bool, glide: Bool = false) {
        guard memory.records.indices.contains(slot), let stack = stacks[memory.records[slot].zoneID] else { return }
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
    /// `forward` (the new window comes in from the right) is the pill's order unless the caller knows better: a cycle
    /// that wraps around keeps going the same way.
    func slideSelect(_ id: CGWindowID, in stack: ZoneStack, forward: Bool? = nil) {
        if isSliding { return extendSlide(to: id, in: stack, forward: forward) }
        guard let carousel, let entering = stack.refs[id], let frontID = stack.activeID, frontID != id,
              let leaving = stack.refs[frontID],
              let from = stack.tabs.firstIndex(where: { $0.id == frontID }), let to = stack.tabs.firstIndex(where: { $0.id == id })
        else { return select(id, in: stack) }
        // The pill moves to the new window now, together with the slide, not once the slide is over.
        stack.activeID = id
        onActivity?(stack.id)
        let rect = stack.rect
        carousel.slide(leaving: leaving, entering: entering, in: rect, forward: forward ?? (to > from)) { [windows] in
            windows.setFrame(rect, of: entering)
            windows.raise(entering)
        }
    }

    /// A choice while a slide runs: if it goes the same way in the same zone, the slide is carried on to the new window (the
    /// pictures of the windows it passed are there already); otherwise the choice is ignored.
    private func extendSlide(to id: CGWindowID, in stack: ZoneStack, forward: Bool?) {
        guard let carousel, let entering = stack.refs[id], let frontID = stack.activeID, frontID != id,
              let from = stack.tabs.firstIndex(where: { $0.id == frontID }), let to = stack.tabs.firstIndex(where: { $0.id == id })
        else { return }
        let forward = forward ?? (to > from)
        let rect = stack.rect
        guard carousel.canExtend(forward: forward, in: rect) else { return }
        stack.activeID = id
        onActivity?(stack.id)
        carousel.extend(entering: entering, forward: forward) { [windows] in
            windows.setFrame(rect, of: entering)
            windows.raise(entering)
        }
    }

    /// Control+Option+Right/Left: the zone of the window in focus moves on to its next window (the previous one when
    /// `reverse`), around the end. A window outside any zone, or a zone with one window, does nothing.
    func cycleFocusedZone(reverse: Bool) {
        guard !placementOnly(), let focused = windows.focusedWindow(), let stack = stack(containing: focused.id), stack.tabs.count > 1 else { return }
        // While a slide runs the window in front is the one it goes to, not the one that is still in focus.
        let current = isSliding ? (stack.activeID ?? focused.id) : focused.id
        guard let from = stack.tabs.firstIndex(where: { $0.id == current }) else { return }
        let count = stack.tabs.count
        slideSelect(stack.tabs[(from + (reverse ? count - 1 : 1)) % count].id, in: stack, forward: !reverse)
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
        guard !isSliding, let focused = windows.focusedWindow(), let stack = stack(containing: focused.id), stack.activeID != focused.id else { return }
        stack.activeID = focused.id
        onActivity?(stack.id)
    }
}
