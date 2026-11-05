import AppKit
import CoreGraphics
import Foundation
import PaneFlipCore

/// The apps of a layout: their icons, starting them, and taking one out of a zone (its window is let go and the restorer places the rest).
final class LayoutAppsService: LayoutAppsEditing {
    private let memory: StackMemory
    private let coordinator: StackCoordinator
    private let apps: AppCatalog
    private let refresher: ZoneRefreshing
    private let iconFont: IconFont
    private let settings: AppSettings
    private let windows: WindowSystem

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
        Set(memory.apps(inZones: layout.strip.zoneIDs).map(\.bundleID)).intersection(layout.startApps).sorted()
    }

    /// An app that is not running is started; one that is running but shows no window (closed with Cmd+W) is asked to open one.
    func open(apps bundleIDs: [String]) {
        let running = Dictionary(apps.regularApps().map { ($0.bundleID, $0.pid) }, uniquingKeysWith: { first, _ in first })
        var started = false
        for bundleID in Set(bundleIDs) where !settings.values.ignoredApps.contains(bundleID) {
            if let pid = running[bundleID], windows.isShowingWindow(ofApp: pid) { continue }
            apps.launch(bundleID: bundleID)
            started = true
        }
        // The windows take a moment to appear, and an app that was not brought to the front is not looked at otherwise.
        guard started else { return }
        for delay in [0.7, 2.0, 4.0] { DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [refresher] in refresher.restoreWindows() } }
    }

    func remove(app bundleID: String, in zone: UUID, inZones zones: [UUID]) {
        changed(memory.removeApp(bundleID, inZone: zone, among: Set(zones)))
    }

    private func changed(_ released: [CGWindowID]) {
        released.forEach(coordinator.removeFromStack)
        refresher.restoreWindows()
    }
}
