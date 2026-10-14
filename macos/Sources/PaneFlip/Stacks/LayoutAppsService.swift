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
        return memory.slots(inZones: zones).map {
            LayoutAppEntry(slot: $0.index, zoneID: $0.zoneID, bundleID: $0.bundleID,
                           name: apps.name(bundleID: $0.bundleID) ?? $0.bundleID, title: $0.title,
                           icon: apps.icon(bundleID: $0.bundleID))
        }
    }

    func runningApps() -> [(bundleID: String, name: String)] {
        apps.regularApps().filter { !$0.bundleID.isEmpty }.map { ($0.bundleID, $0.name) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func addApp(bundleID: String, to zone: UUID) {
        memory.remember(zoneID: zone, bundleID: bundleID, title: "")
        changed([])
    }

    func move(slot: Int, to zone: UUID, inZones zones: [UUID]) {
        changed([memory.assign(slot: slot, toZone: zone, among: Set(zones))].compactMap { $0 })
    }

    func reorder(slot: Int, by offset: Int, inZones zones: [UUID]) {
        changed(memory.moveSlot(slot, by: offset, among: Set(zones)))
    }

    func remove(slot: Int) {
        changed([memory.removeSlot(slot)].compactMap { $0 })
    }

    private func changed(_ released: [CGWindowID]) {
        released.forEach(coordinator.removeFromStack)
        revision += 1
        refresher.restoreWindows()
    }
}
