import Foundation
import PaneFlipCore

/// Puts running windows back into the zones they were remembered in (after PaneFlip or an app relaunched),
/// in the order of the memory, which is the order the user arranged.
final class WindowRestorer {
    private let windows: WindowSystem
    private let apps: AppCatalog
    private let screens: ScreenProviding
    private let memory: StackMemory
    private let coordinator: StackCoordinator
    private let availability: WindowAvailability
    private let settings: AppSettings

    init(windows: WindowSystem, apps: AppCatalog, screens: ScreenProviding, memory: StackMemory, coordinator: StackCoordinator,
         availability: WindowAvailability, settings: AppSettings) {
        self.windows = windows
        self.apps = apps
        self.screens = screens
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

        let displays = screens.screens().map(\.axVisible)
        func display(of rect: CGRect) -> Int? { displays.firstIndex { $0.contains(CGPoint(x: rect.midX, y: rect.midY)) } }

        var touched: Set<UUID> = []
        for slot in slots {
            let record = memory.records[slot]
            guard var free = candidates[record.bundleID], !free.isEmpty else { continue }
            // Without stacking a zone holds one window: leave later slots of an already-filled zone waiting.
            if !settings.values.stackingEnabled, coordinator.stacks[record.zoneID]?.isEmpty == false { continue }
            // A window stays on the display it is on: one on another display than the zone is left alone. Among the
            // others, the one already inside the zone comes first, then the one with the remembered title.
            let zone = coordinator.stacks[record.zoneID]?.rect
            let zoneDisplay = zone.flatMap(display(of:))
            var best: (index: Int, score: Int)?
            for (i, window) in free.enumerated() {
                let frame = windows.frame(of: window)
                if let zoneDisplay, let frame, let there = display(of: frame), there != zoneDisplay { continue }
                var score = 0
                if let zone, let frame, zone.contains(CGPoint(x: frame.midX, y: frame.midY)) { score += 2 }
                if windows.title(of: window) == record.title { score += 1 }
                if best == nil || score > best!.score { best = (i, score) }
            }
            guard let pick = best?.index else { continue }
            coordinator.attach(free[pick], toSlot: slot, raise: false)
            touched.insert(record.zoneID)
            free.remove(at: pick)
            candidates[record.bundleID] = free
        }
        for id in touched { coordinator.stacks[id].map(coordinator.followFrontmost) }
    }
}
