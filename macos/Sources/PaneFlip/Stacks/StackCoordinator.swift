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
    var isSliding: Bool { carousel?.isSliding ?? false }

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
        visibleZoneIDs = Set(zones.keys)
        for (id, rect) in zones {
            let stack = stacks[id] ?? ZoneStack(id: id)
            stacks[id] = stack
            stack.rect = rect
            for tab in stack.tabs {
                guard let ref = stack.refs[tab.id] else { continue }
                glide?.cancel(ref.id)
                windows.setFrame(stack.rect, of: ref)
            }
        }
    }

    var visibleStacks: [ZoneStack] { visibleZoneIDs.compactMap { stacks[$0] } }

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
        guard settings.values.placementEnabled, stacks[zoneID] != nil else { return }
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
        if glide, raise, let mover = self.glide {
            stack.activeID = ref.id
            windows.raise(ref)
            mover.glide(ref, to: stack.rect)
            onActivity?(stack.id)
            return
        }
        windows.setFrame(stack.rect, of: ref)
        if raise { select(ref.id, in: stack) } else { onActivity?(stack.id) }
    }

    /// A pill appeared: the next click will slide.
    func prepareSlides() { carousel?.prepare() }

    /// A click on the pill: the chosen window slides in beside the one in front. Without a carousel, or when there
    /// is nothing to slide past, it simply comes to the front.
    /// `forward` (the new window comes in from the right) is the pill's order unless the caller knows better: a cycle
    /// that wraps around keeps going the same way.
    func slideSelect(_ id: CGWindowID, in stack: ZoneStack, forward: Bool? = nil) {
        if isSliding { return }   // a click during a slide is ignored
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

    /// Control+Option+Right/Left: the zone of the window in focus moves on to its next window (the previous one when
    /// `reverse`), around the end. A window outside any zone, or a zone with one window, does nothing.
    func cycleFocusedZone(reverse: Bool) {
        guard let focused = windows.focusedWindow(), let stack = stack(containing: focused.id), stack.tabs.count > 1,
              let from = stack.tabs.firstIndex(where: { $0.id == focused.id }) else { return }
        let count = stack.tabs.count
        slideSelect(stack.tabs[(from + (reverse ? count - 1 : 1)) % count].id, in: stack, forward: !reverse)
    }

    func select(_ id: CGWindowID, in stack: ZoneStack) {
        guard let ref = stack.refs[id] else { return }
        stack.activeID = id
        windows.setFrame(stack.rect, of: ref)
        windows.raise(ref)
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
        guard !isSliding, let focused = windows.focusedWindow(), let stack = stack(containing: focused.id), stack.activeID != focused.id else { return }
        stack.activeID = focused.id
        onActivity?(stack.id)
    }
}
