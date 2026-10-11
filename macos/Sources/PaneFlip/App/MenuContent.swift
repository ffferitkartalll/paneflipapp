import AppKit
import SwiftUI

/// The menu bar menu: the app's name, Settings and Quit, each group set apart by a divider.
struct MenuContent: View {
    var body: some View {
        Button("PaneFlip") {}
            .disabled(true)
        Divider()
        SettingsLink { Text("Settings") }
        Divider()
        Button("Quit") { NSApp.terminate(nil) }
    }
}
