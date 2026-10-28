import AppKit
import PaneFlipCore
import SwiftUI

/// The menu bar menu: the app's name, the on/off switch, the layout switcher and layout actions, Settings and Quit, each group set apart by a divider.
struct MenuContent: View {
    let repository: LayoutRepository
    let layouts: LayoutManaging
    let screens: ScreenProviding
    @Bindable var settings: AppSettings
    let apps: LayoutAppsEditing
    let editor: LayoutEditing
    let openSettings: () -> Void

    var body: some View {
        Button("PaneFlip") {}
            .disabled(true)
        Toggle("Enable", isOn: $settings.values.placementEnabled)
        Divider()
        MenuLayouts(repository: repository, layouts: layouts, screens: screens)
        let toStart = screens.screens().compactMap { repository.activeLayout(for: $0.key) }.flatMap { apps.startApps(of: $0) }
        Button("Edit layout") { editor.toggleAtPointer() }
        Button("Open selected apps") { apps.open(apps: toStart) }
            .disabled(toStart.isEmpty)
        Divider()
        Button("Settings", action: openSettings)
            .keyboardShortcut(",")
        Divider()
        Button("Quit") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}
