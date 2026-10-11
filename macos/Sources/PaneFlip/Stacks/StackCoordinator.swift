import CoreGraphics
import Foundation
import PaneFlipCore

/// The live stacks of every zone and the operations on them: snap, select, release, reorder.
/// It is the only place where the persistent memory (`StackMemory`) and real windows are kept in step.
final class StackCoordinator {
    private(set) var stacks: [UUID: ZoneStack] = [:]
    private(set) var visibleZoneIDs: Set<UUID> = []
    /// Called when a stack changed in a way the pill should announce (window added, tab switched).
    var onActivity: ((UUID) -> Void)?

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
            for tab in stack.tabs { if let ref = stack.refs[tab.id] { windows.setFrame(rect, of: ref) } }
        }
    }

    var visibleStacks: [ZoneStack] { visibleZoneIDs.compactMap { stacks[$0] } }

    func zoneID(at point: CGPoint) -> UUID? {
        visibleStacks.first { $0.rect.insetBy(dx: -4, dy: -4).contains(point) }?.id
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
        guard settings.placementEnabled, stacks[zoneID] != nil else { return }
        unsnap(window: ref.id)
        // Without stacking a zone holds one app: the newcomer replaces whatever was there.
        if !settings.stackingEnabled, let current = stacks[zoneID] {
            for id in Array(current.refs.keys) { unsnap(window: id) }
        }
        let slot = memory.remember(zoneID: zoneID, bundleID: apps.app(pid: ref.pid)?.bundleID ?? "", title: "")
        attach(ref, toSlot: slot, raise: true)
    }

    /// Puts a live window into the zone its memory slot names, at the position the user arranged.
    func attach(_ ref: WindowRef, toSlot slot: Int, raise: Bool) {
        guard memory.records.indices.contains(slot), let stack = stacks[memory.records[slot].zoneID] else { return }
        let appName = apps.app(pid: ref.pid)?.name ?? "?"
        let title = windows.title(of: ref) ?? appName
        memory.bind(slot: slot, toWindow: ref.id, title: title)
        stack.refs[ref.id] = ref
        let position = stack.tabs.filter { (memory.index(ofWindow: $0.id) ?? Int.max) < slot }.count
        stack.tabs.insert(.init(id: ref.id, title: title, appName: appName, icon: apps.icon(pid: ref.pid)), at: position)
        stack.refreshNames()
        if stack.activeID == nil { stack.activeID = ref.id }
        windows.setFrame(stack.rect, of: ref)
        if raise { select(ref.id, in: stack) } else { onActivity?(stack.id) }
    }

    func select(_ id: CGWindowID, in stack: ZoneStack) {
        guard let ref = stack.refs[id] else { return }
        stack.activeID = id
        windows.setFrame(stack.rect, of: ref)
        windows.raise(ref)
        onActivity?(stack.id)
    }

    /// Takes a window out of its zone for good (the window itself stays open).
    func unsnap(window id: CGWindowID) {
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

    func persistOrder(of stack: ZoneStack) {
        memory.applyOrder(zoneID: stack.id, windowOrder: stack.tabs.map(\.id))
    }

    /// Picks up window title changes.
    func syncTitles() {
        for stack in stacks.values {
            for (i, tab) in stack.tabs.enumerated() {
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
        guard let focused = windows.focusedWindow(), let stack = stack(containing: focused.id), stack.activeID != focused.id else { return }
        stack.activeID = focused.id
        onActivity?(stack.id)
    }
}
