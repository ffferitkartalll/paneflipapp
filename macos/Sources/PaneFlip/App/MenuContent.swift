import AppKit
import PaneFlipCore
import SwiftUI

/// The menu bar menu: the app's name, the on/off switch, the layout switcher, Settings and Quit, each group set apart by a divider.
struct MenuContent: View {
    let repository: LayoutRepository
    let layouts: LayoutManaging
    let screens: ScreenProviding
    @Bindable var settings: AppSettings

    var body: some View {
        Button("PaneFlip") {}
            .disabled(true)
        Toggle("Enable", isOn: $settings.values.placementEnabled)
        Divider()
        MenuLayouts(repository: repository, layouts: layouts, screens: screens)
        SettingsLink { Text("Settings") }
        Divider()
        Button("Quit") { NSApp.terminate(nil) }
    }
}
