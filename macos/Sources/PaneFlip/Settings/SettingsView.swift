import PaneFlipCore
import SwiftUI

/// The Settings window. Icon tabs in the toolbar, one concern per tab. The width is fixed; the height follows the
/// selected tab's content, so the window grows and shrinks as you switch tabs.
struct SettingsView: View {
    let repository: LayoutRepository
    let layouts: LayoutManaging
    let editor: LayoutEditing
    let screens: ScreenProviding
    let refresh: () -> Void
    let settings: AppSettings
    let launchAtLogin: LaunchAtLoginModel
    let activation: ActivationPolicyControlling

    var body: some View {
        TabView {
            GeneralPane(settings: settings, launchAtLogin: launchAtLogin)
                .fixedSize(horizontal: false, vertical: true)
                .tabItem { Label("General", systemImage: "gearshape") }

            LayoutsPane(repository: repository, layouts: layouts, editor: editor, screens: screens,
                        refresh: refresh, settings: settings)
                .fixedSize(horizontal: false, vertical: true)
                .tabItem { Label("Layouts", systemImage: "rectangle.split.2x2") }

            PlacementPane(settings: settings)
                .fixedSize(horizontal: false, vertical: true)
                .tabItem { Label("Placement", systemImage: "square.and.arrow.down") }

            StackingPane(settings: settings)
                .fixedSize(horizontal: false, vertical: true)
                .tabItem { Label("Stacking", systemImage: "square.stack.3d.up") }
        }
        .scenePadding()
        .frame(width: 640)
        .background(FixedWindowTitle(title: String(localized: "Settings")))
        .background(WindowPresenceReporter(activation: activation))
        .onAppear { NSApp.activate(ignoringOtherApps: true) }
    }
}
