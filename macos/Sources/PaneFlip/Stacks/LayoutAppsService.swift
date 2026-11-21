import AppKit
import CoreGraphics
import Foundation
import Observation
import PaneFlipCore

/// The apps of a layout: their icons, starting them, and changing their zones and order (a window whose slot changed is let go and the restorer places it again).
@Observable
final class LayoutAppsService: LayoutAppsEditing {
    /// Which scene is in use and the memory of another one (set where the scenes exist): without them every scene is the one in use.
    @ObservationIgnored var scenes: (active: () -> UUID, memory: (UUID) -> StackMemory)?

    /// Changes whenever the apps changed: a view that listed them (`entries`) is drawn again.
    private var revision = 0

    @ObservationIgnored private let memory: StackMemory
    @ObservationIgnored private let coordinator: StackCoordinator
    @ObservationIgnored private let apps: AppCatalog
    @ObservationIgnored private let refresher: ZoneRefreshing
    @ObservationIgnored private let iconFont: IconFont
    @ObservationIgnored private let settings: AppSettings
    @ObservationIgnored private let windows: WindowSystem

    init(memory: StackMemory, coordinator: StackCoordinator, apps: AppCatalog, refresher: ZoneRefreshing, iconFont: IconFont,
         settings: AppSettings, windows: WindowSystem) {
        self.memory = memory
        self.coordinator = coordinator
        self.apps = apps
        self.refresher = refresher
        self.iconFont = iconFont
        self.settings = settings
        self.windows = windows
    }

    func editing(scene: UUID) -> LayoutAppsEditing {
        guard let scenes, scenes.active() != scene else { return self }
        // Read afresh each time: the scene may have been in use since. Its slots wait for windows, so nothing live is touched.
        let other = LayoutAppsService(memory: scenes.memory(scene), coordinator: coordinator, apps: apps, refresher: refresher, iconFont: iconFont, settings: settings, windows: windows)
        other.scenes = (active: scenes.active, memory: scenes.memory)
        return other
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

    func launch(app bundleID: String, into zone: UUID) {
        add(app: bundleID, to: zone)
        open(apps: [bundleID])
    }

    func add(app bundleID: String, to zone: UUID) {
        if !memory.slots(inZone: zone).contains(where: { $0.bundleID == bundleID }) {
            _ = memory.remember(zoneID: zone, bundleID: bundleID, title: apps.name(bundleID: bundleID) ?? bundleID)
        }
        changed([])
    }

    func glyph(ofApp bundleID: String) -> NSImage {
        glyph(bundleID: bundleID, name: apps.name(bundleID: bundleID) ?? bundleID)
    }

    /// The icon as the island draws it: a one-colour glyph, which follows the text colour.
    private func glyph(bundleID: String, name: String) -> NSImage {
        let icon = apps.icon(bundleID: bundleID) ?? NSWorkspace.shared.icon(for: .applicationBundle)
        let image = iconFont.image(bundleID: bundleID, appName: name, icon: icon, size: 18)
        image.isTemplate = true
        return image
    }

    func startApps(of layout: NamedLayout) -> [String] {
        memory.startApps(inZones: layout.strip.zoneIDs).sorted()
    }

    func setStart(_ chosen: Bool, app bundleID: String, inZones zones: [UUID]) {
        memory.setStart(chosen, app: bundleID, inZones: zones)
        revision += 1
    }

    /// An app that is not running is started; one that is running but shows no window (closed with Cmd+W) is asked to open one.
    func open(apps bundleIDs: [String]) {
        let running = Dictionary(apps.regularApps().map { ($0.bundleID, $0.pid) }, uniquingKeysWith: { first, _ in first })
        var started = false
        for bundleID in Set(bundleIDs) where !settings.values.ignoredApps.contains(bundleID) {
            if let pid = running[bundleID], windows.isShowingWindow(ofApp: pid) { continue }
            apps.launch(bundleID: bundleID)
            coordinator.noteOpened(app: bundleID)
            started = true
        }
        // The windows take a moment to appear, and an app that was not brought to the front is not looked at otherwise.
        guard started else { return }
        for delay in [0.7, 2.0, 4.0] { DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [refresher] in refresher.restoreWindows() } }
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

    func clear(zones: [UUID]) {
        changed(memory.forget(zones: Set(zones)))
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
