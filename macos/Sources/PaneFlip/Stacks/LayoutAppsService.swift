import CoreGraphics
import Foundation
import Observation
import PaneFlipCore

/// Edits the memory of which app belongs in which zone, layout by layout, and keeps the live stacks in step: a
/// window whose slot changed is let go and attached again by the restorer, in the memory's order.
@Observable
final class LayoutAppsService: LayoutAppsEditing {
    private(set) var revision = 0

    @ObservationIgnored private let memory: StackMemory
    @ObservationIgnored private let coordinator: StackCoordinator
    @ObservationIgnored private let apps: AppCatalog
    @ObservationIgnored private let refresher: ZoneRefreshing

    init(memory: StackMemory, coordinator: StackCoordinator, apps: AppCatalog, refresher: ZoneRefreshing) {
        self.memory = memory
        self.coordinator = coordinator
        self.apps = apps
        self.refresher = refresher
    }

    func entries(inZones zones: [UUID]) -> [LayoutAppEntry] {
        _ = revision
        return memory.apps(inZones: zones).map { app in
            LayoutAppEntry(zoneID: app.zoneID, bundleID: app.bundleID,
                           name: apps.name(bundleID: app.bundleID) ?? app.bundleID,
                           icon: apps.icon(bundleID: app.bundleID),
                           // Only the open windows: a closed one is not worth ordering.
                           windows: app.slots.filter { $0.windowID != nil }.map { .init(slot: $0.index, title: $0.title) })
        }
    }

    func runningApps() -> [(bundleID: String, name: String)] {
        apps.regularApps().filter { !$0.bundleID.isEmpty }.map { ($0.bundleID, $0.name) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func addApp(bundleID: String, to zone: UUID) {
        // An app is listed once per zone.
        guard !memory.slots(inZones: [zone]).contains(where: { $0.bundleID == bundleID }) else { return }
        memory.remember(zoneID: zone, bundleID: bundleID, title: "")
        changed([])
    }

    func move(app bundleID: String, from zone: UUID, to target: UUID, inZones zones: [UUID]) {
        changed(memory.assignApp(bundleID, inZone: zone, toZone: target, among: Set(zones)))
    }

    func reorder(app bundleID: String, in zone: UUID, by offset: Int, inZones zones: [UUID]) {
        changed(memory.moveApp(bundleID, inZone: zone, by: offset, among: Set(zones)))
    }

    func reorder(window slot: Int, by offset: Int, inZones zones: [UUID]) {
        changed(memory.moveWindow(slot, by: offset, among: Set(zones)))
    }

    func remove(app bundleID: String, in zone: UUID, inZones zones: [UUID]) {
        changed(memory.removeApp(bundleID, inZone: zone, among: Set(zones)))
    }

    private func changed(_ released: [CGWindowID]) {
        released.forEach(coordinator.removeFromStack)
        revision += 1
        refresher.restoreWindows()
    }
}
