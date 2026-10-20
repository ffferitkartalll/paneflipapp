import AppKit
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
    @ObservationIgnored private let iconFont: IconFont
    @ObservationIgnored private let settings: AppSettings

    init(memory: StackMemory, coordinator: StackCoordinator, apps: AppCatalog, refresher: ZoneRefreshing, iconFont: IconFont,
         settings: AppSettings) {
        self.memory = memory
        self.coordinator = coordinator
        self.apps = apps
        self.refresher = refresher
        self.iconFont = iconFont
        self.settings = settings
    }

    func entries(inZones zones: [UUID]) -> [LayoutAppEntry] {
        _ = revision
        return memory.apps(inZones: zones).map { app in
            let name = apps.name(bundleID: app.bundleID) ?? app.bundleID
            return LayoutAppEntry(zoneID: app.zoneID, bundleID: app.bundleID, name: name, icon: glyph(bundleID: app.bundleID, name: name),
                           // Only the open windows: a closed one is not worth ordering.
                           windows: app.slots.filter { $0.windowID != nil }.map { .init(slot: $0.index, title: $0.title) })
        }
    }

    func glyph(ofApp bundleID: String) -> NSImage {
        glyph(bundleID: bundleID, name: apps.name(bundleID: bundleID) ?? bundleID)
    }

    /// The icon as the pill draws it: a one-colour glyph, which follows the text colour.
    private func glyph(bundleID: String, name: String) -> NSImage {
        let icon = apps.icon(bundleID: bundleID) ?? NSWorkspace.shared.icon(for: .applicationBundle)
        let image = iconFont.image(bundleID: bundleID, appName: name, icon: icon, size: 18)
        image.isTemplate = true
        return image
    }

    func runningApps() -> [(bundleID: String, name: String)] {
        apps.regularApps().filter { !$0.bundleID.isEmpty && !settings.values.ignoredApps.contains($0.bundleID) }.map { ($0.bundleID, $0.name) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func addApp(bundleID: String, to zone: UUID) {
        // An app is listed once per zone.
        guard !memory.slots(inZones: [zone]).contains(where: { $0.bundleID == bundleID }),
              !settings.values.ignoredApps.contains(bundleID) else { return }
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
