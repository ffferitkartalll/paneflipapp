import Foundation
import PaneFlipCore

/// Puts running windows back into the zones they were remembered in (after PaneFlip or an app relaunched),
/// in the order of the memory, which is the order the user arranged.
final class WindowRestorer {
    private let windows: WindowSystem
    private let apps: AppCatalog
    private let memory: StackMemory
    private let coordinator: StackCoordinator
    private let availability: WindowAvailability
    private let settings: AppSettings

    init(windows: WindowSystem, apps: AppCatalog, memory: StackMemory, coordinator: StackCoordinator,
         availability: WindowAvailability, settings: AppSettings) {
        self.windows = windows
        self.apps = apps
        self.memory = memory
        self.coordinator = coordinator
        self.availability = availability
        self.settings = settings
    }

    func restore() {
        guard windows.isTrusted, settings.values.placementEnabled else { return }
        let slots = memory.unboundSlots(in: coordinator.visibleZoneIDs)
        guard !slots.isEmpty else { return }

        // Windows available per app. A window its app merely hid on close still shows up in the accessibility
        // list; it isn't back until it is visible again.
        let bundles = Set(slots.map { memory.records[$0].bundleID })
        let claimed = memory.boundWindowIDs
        let snapshot = availability.snapshot()
        var candidates: [String: [WindowRef]] = [:]
        for app in apps.regularApps() where bundles.contains(app.bundleID) {
            let free = windows.windows(ofApp: app.pid).filter { !claimed.contains($0.id) && !availability.isGone($0, in: snapshot) }
            if !free.isEmpty { candidates[app.bundleID, default: []] += free }
        }

        var touched: Set<UUID> = []
        for slot in slots {
            let record = memory.records[slot]
            guard var free = candidates[record.bundleID], !free.isEmpty else { continue }
            // Without stacking a zone holds one window: leave later slots of an already-filled zone waiting.
            if !settings.values.stackingEnabled, coordinator.stacks[record.zoneID]?.isEmpty == false { continue }
            let pick = free.firstIndex { windows.title(of: $0) == record.title } ?? 0
            coordinator.attach(free[pick], toSlot: slot, raise: false)
            touched.insert(record.zoneID)
            free.remove(at: pick)
            candidates[record.bundleID] = free
        }
        for id in touched { coordinator.stacks[id].map(coordinator.followFrontmost) }
    }
}
