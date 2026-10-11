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
        MenuBarExtra("PaneFlip", systemImage: "rectangle.split.2x2") {
            MenuContent()
        }

        // Opened from the menu bar menu (Settings).
        Settings {
            SettingsView(repository: container.layoutRepository, layouts: container.layouts, editor: container.editor,
                         screens: container.screens, refresh: { container.engine.refreshZones() },
                         settings: container.settings, launchAtLogin: container.launchAtLogin,
                         activation: container.activation)
        }
    }
}
