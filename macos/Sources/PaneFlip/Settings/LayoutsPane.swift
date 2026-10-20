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
    /// Bumped when displays are plugged in or out or desktops change, so the list of screens is read again.
    @State private var displaysChanged = 0

    var body: some View {
        let _ = displaysChanged
        Form {
            ForEach(screens.screens()) { screen in
                ScreenLayoutsSection(screen: screen, repository: repository, layouts: layouts, editor: editor, apps: apps,
                                     navigation: navigation, showsOverflow: settings.values.overflowZonesEnabled, defaultGap: settings.values.gap)
            }
        }
        .formStyle(.grouped)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)) { _ in
            displaysChanged += 1
        }
        // A desktop added or removed in Mission Control changes neither the displays nor the screen parameters.
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.activeSpaceDidChangeNotification)) { _ in
            displaysChanged += 1
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            displaysChanged += 1
        }
    }
}
