import CoreGraphics
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

    /// Free windows last seen of the frontmost app, so an unchanged situation is not worked out again.
    private var lastFree: Set<CGWindowID> = []

    /// Cheap check for the app in front, run on every tick: a new window of an app that has a zone goes there.
    func restoreFrontmost() {
        guard windows.isTrusted, settings.values.placementEnabled, !coordinator.placementOnly(), let pid = apps.frontmostPID,
              let app = apps.app(pid: pid),
              memory.records.contains(where: { $0.bundleID == app.bundleID && coordinator.visibleZoneIDs.contains($0.zoneID) })
        else { return }
        let claimed = memory.boundWindowIDs
        let free = Set(windows.windows(ofApp: pid).map(\.id)).subtracting(claimed).subtracting(coordinator.pulledOut)
        guard free != lastFree else { return }
        lastFree = free
        if !free.isEmpty { restore(onlyApp: pid) }
    }

    /// Puts running windows into the zones their apps belong in: a window of an app with a waiting slot takes that
    /// slot (in the order of the memory), and any other window of such an app joins the zone of the app's first
    /// remembered window. `onlyApp` limits it to one app.
    func restore(onlyApp onlyPID: pid_t? = nil) {
        guard windows.isTrusted, settings.values.placementEnabled, !coordinator.placementOnly() else { return }
        let visible = coordinator.visibleZoneIDs
        // The zone an app belongs in: where its first remembered window is.
        var ruleZone: [String: UUID] = [:]
        for record in memory.records where visible.contains(record.zoneID) && !record.bundleID.isEmpty {
            if ruleZone[record.bundleID] == nil { ruleZone[record.bundleID] = record.zoneID }
        }
        guard !ruleZone.isEmpty else { return }
        let slots = memory.unboundSlots(in: visible)

        // Windows available per app. A window its app merely hid on close still shows up in the accessibility
        // list; it isn't back until it is visible again.
        let claimed = memory.boundWindowIDs
        let snapshot = availability.snapshot()
        var candidates: [String: [WindowRef]] = [:]
        for app in apps.regularApps() where ruleZone[app.bundleID] != nil && (onlyPID == nil || app.pid == onlyPID) {
            let free = windows.windows(ofApp: app.pid).filter {
                !claimed.contains($0.id) && !coordinator.pulledOut.contains($0.id) && !availability.isGone($0, in: snapshot)
            }
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

        // The app's other windows, however many: they join its zone, next to the app's other windows.
        for (bundleID, free) in candidates {
            guard let zoneID = ruleZone[bundleID], let stack = coordinator.stacks[zoneID] else { continue }
            let zoneDisplay = display(of: stack.rect)
            for window in free {
                if !settings.values.stackingEnabled, !stack.isEmpty { break }
                if let zoneDisplay, let frame = windows.frame(of: window), let there = display(of: frame), there != zoneDisplay { continue }
                let slot = memory.remember(zoneID: zoneID, bundleID: bundleID, title: "")
                coordinator.attach(window, toSlot: slot, raise: false)
                touched.insert(zoneID)
            }
        }
        for id in touched { coordinator.stacks[id].map(coordinator.followFrontmost) }
    }
}
