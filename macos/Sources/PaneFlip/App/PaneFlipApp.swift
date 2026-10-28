import AppKit
import SwiftUI

@main
struct PaneFlipApp: App {
    private let container = AppContainer()

    init() {
        // Start once the app has finished launching; nothing needs to be opened by the user first.
        let container = container
        NotificationCenter.default.addObserver(forName: NSApplication.didFinishLaunchingNotification, object: nil, queue: .main) { _ in
            container.start()
        }
    }

    var body: some Scene {
        // Opened from the menu bar menu (Settings).
        Settings {
            SettingsView(repository: container.layoutRepository, layouts: container.layouts, editor: container.editor, apps: container.layoutApps,
                         screens: container.screens, refresh: { container.engine.refreshZones() },
                         settings: container.settings, launchAtLogin: container.launchAtLogin, relauncher: container.relauncher, catalog: container.appCatalog, updates: container.updates,
                         activation: container.activation, navigation: container.settingsNavigation)
        }
    }
}
