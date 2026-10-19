import AppKit
import PaneFlipCore
import SwiftUI

/// Tab: the layouts of every screen and the geometry options that shape their zones.
struct LayoutsPane: View {
    let repository: LayoutRepository
    let layouts: LayoutManaging
    let editor: LayoutEditing
    let apps: LayoutAppsEditing
    let screens: ScreenProviding
    @Bindable var settings: AppSettings
    let navigation: SettingsNavigation
    /// Bumped when displays are plugged in or out, so the list of screens is read again.
    @State private var displaysChanged = 0

    var body: some View {
        let _ = displaysChanged
        Form {
            ForEach(screens.screens()) { screen in
                ScreenLayoutsSection(screen: screen, repository: repository, layouts: layouts, editor: editor, apps: apps,
                                     navigation: navigation, showsOverflow: settings.values.overflowZonesEnabled)
            }
        }
        .formStyle(.grouped)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)) { _ in
            displaysChanged += 1
        }
    }
}
