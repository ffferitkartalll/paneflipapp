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
              let app = apps.app(pid: pid), !settings.values.ignoredApps.contains(app.bundleID),
              memory.records.contains(where: { $0.bundleID == app.bundleID && coordinator.visibleZoneIDs.contains($0.zoneID) })
        else { return }
        guard let background else { return decide(from: windows.windows(ofApp: pid), of: pid) }
        // The app's windows are asked off the main thread, one round at a time: an app that is slow to answer must not hold the app. And not again for a few seconds
        // when it was slow: asking every half second keeps an app busy that has no time for it.
        guard !asking, slowUntil[pid].map({ ProcessInfo.processInfo.systemUptime >= $0 }) ?? true else { return }
        asking = true
        background { [windows] in
            let began = CFAbsoluteTimeGetCurrent()
            let list = windows.windows(ofApp: pid)
            let slow = CFAbsoluteTimeGetCurrent() - began > 0.1
            DispatchQueue.main.async { [self] in
                asking = false
                if slow { slowUntil[pid] = ProcessInfo.processInfo.systemUptime + 3 }
                decide(from: list, of: pid)
            }
        }
    }

    private func decide(from list: [WindowRef], of pid: pid_t) {
        let free = Set(list.map(\.id)).subtracting(memory.boundWindowIDs).subtracting(coordinator.pulledOut)
        guard free != lastFree else { return }
        lastFree = free
        if !free.isEmpty { restore(onlyApp: pid) }
    }

    /// `restore(onlyApp:)` for an app that has just come: its windows are asked off the main thread first. An app that is slow to answer (one
    /// still busy bringing its window up) would otherwise hold the main thread, and with it everything that is drawn.
    func restoreAfterListing(app pid: pid_t) {
        guard let background else { return restore(onlyApp: pid) }
        background { [windows] in
            let list = windows.windows(ofApp: pid)
            DispatchQueue.main.async { [self] in restore(onlyApp: pid, listed: [pid: list]) }
        }
    }

    /// `restore()` for every app: the windows of all of them are asked off the main thread first (one app that is slow to answer, a mail client, took a quarter of a second
    /// of the main thread's time, and the apps are many).
    func restoreAfterListingAll() {
        guard let background else { return restore() }
        let ignored = Set(settings.values.ignoredApps)
        let bundleIDs = Set(memory.records.map(\.bundleID).filter { !$0.isEmpty && !ignored.contains($0) })
        let pids = apps.regularApps(withBundleIDs: bundleIDs).map(\.pid)
        background { [windows] in
            var listed: [pid_t: [WindowRef]] = [:]
            for pid in pids { listed[pid] = windows.windows(ofApp: pid) }
            DispatchQueue.main.async { [self] in restore(listed: listed) }
        }
    }

    /// Runs the question to an app for its windows off the main thread (nil: where it is asked, in tests).
    var background: ((@escaping () -> Void) -> Void)?
    private var asking = false
    /// Apps that were slow to list their windows, and until when they are left alone at the checks of every tick.
    private var slowUntil: [pid_t: TimeInterval] = [:]

    /// Puts running windows into the zones their apps belong in: a window of an app with a waiting slot takes that
    /// slot (in the order of the memory), and any other window of such an app joins the zone of the app's first
    /// remembered window. `onlyApp` limits it to one app.
    func restore(onlyApp onlyPID: pid_t? = nil, listed: [pid_t: [WindowRef]] = [:]) {
        guard windows.isTrusted, settings.values.placementEnabled, !coordinator.placementOnly() else { return }
        let visible = coordinator.visibleZoneIDs
        // The zone an app belongs in: where its first remembered window is.
        var ruleZone: [String: UUID] = [:]
        let ignored = Set(settings.values.ignoredApps)
        for record in memory.records where visible.contains(record.zoneID) && !record.bundleID.isEmpty && !ignored.contains(record.bundleID) {
            if ruleZone[record.bundleID] == nil { ruleZone[record.bundleID] = record.zoneID }
        }
        guard !ruleZone.isEmpty else { return }
        // A window that left with its display goes first: to the slot it left, before another slot of its app can take it.
        let own = Set(coordinator.displacedWindows.compactMap { coordinator.displacedSlot(of: $0.id) })
        let unbound = memory.unboundSlots(in: visible)
        let slots = unbound.filter { own.contains(memory.records[$0].id) } + unbound.filter { !own.contains(memory.records[$0].id) }

        // Windows available per app. A window its app merely hid on close still shows up in the accessibility
        // list; it isn't back until it is visible again.
        let claimed = memory.boundWindowIDs
        let snapshot = availability.snapshot()
        var candidates: [String: [WindowRef]] = [:]
        for app in apps.regularApps(withBundleIDs: Set(ruleZone.keys)) where onlyPID == nil || app.pid == onlyPID {
            let free = (listed[app.pid] ?? windows.windows(ofApp: app.pid)).filter {
                !claimed.contains($0.id) && !coordinator.pulledOut.contains($0.id) && !availability.isGone($0, in: snapshot)
            }
            if !free.isEmpty { candidates[app.bundleID, default: []] += free }
        }

        // A window that left with its display is known by name: the app's window list may not show it for a while after the display is back
        // (the app is busy, or the system has not yet put the window on screen), and it must not be taken for a closed one then.
        for ref in coordinator.displacedWindows where !claimed.contains(ref.id) && (onlyPID == nil || ref.pid == onlyPID) {
            guard let bundleID = apps.app(pid: ref.pid)?.bundleID, ruleZone[bundleID] != nil, windows.frame(of: ref) != nil,
                  !windows.isMinimized(ref), !apps.isHidden(pid: ref.pid), !candidates[bundleID, default: []].contains(where: { $0.id == ref.id }) else { continue }
            candidates[bundleID, default: []].append(ref)
        }
        let displays = screens.screens().map(\.axVisible)
        func display(of rect: CGRect) -> Int? { displays.firstIndex { $0.contains(CGPoint(x: rect.midX, y: rect.midY)) } }

        var touched: Set<UUID> = []
        for slot in slots {
            let record = memory.records[slot]
            guard var free = candidates[record.bundleID], !free.isEmpty else { continue }
            // A window stays on the display it is on: one on another display than the zone is left alone. Among the
            // others, the one already inside the zone comes first, then the one with the remembered title.
            let zone = coordinator.stacks[record.zoneID]?.rect
            let zoneDisplay = zone.flatMap(display(of:))
            var best: (index: Int, score: Int)?
            for (i, window) in free.enumerated() {
                let frame = windows.frame(of: window)
                // A window that left with its display takes the slot it left and no other.
                if coordinator.isDisplaced(window.id), coordinator.displacedSlot(of: window.id) != record.id { continue }
                if let zoneDisplay, !coordinator.isDisplaced(window.id), let frame, let there = display(of: frame), there != zoneDisplay { continue }
                var score = 0
                if let zone, let frame, zone.contains(CGPoint(x: frame.midX, y: frame.midY)) { score += 2 }
                if windows.title(of: window) == record.title { score += 1 }
                if best == nil || score > best!.score { best = (i, score) }
            }
            guard let pick = best?.index else { continue }
            coordinator.attach(free[pick], toSlot: slot, raise: false)
            coordinator.settled(free[pick].id)
            touched.insert(record.zoneID)
            free.remove(at: pick)
            candidates[record.bundleID] = free
        }

        // The app's other windows, however many: they join its zone, next to the app's other windows.
        for (bundleID, free) in candidates {
            guard let zoneID = ruleZone[bundleID], let stack = coordinator.stacks[zoneID] else { continue }
            let zoneDisplay = display(of: stack.rect)
            for window in free {
                // A window that left with its display goes back to its own slot only: before the display's zones are in view it must not join another zone.
                if coordinator.isDisplaced(window.id) { continue }
                if let zoneDisplay, let frame = windows.frame(of: window), let there = display(of: frame), there != zoneDisplay { continue }
                let slot = memory.remember(zoneID: zoneID, bundleID: bundleID, title: "")
                coordinator.attach(window, toSlot: slot, raise: false)
                touched.insert(zoneID)
            }
        }
        for id in touched { coordinator.stacks[id].map(coordinator.followFrontmost) }
    }
}
