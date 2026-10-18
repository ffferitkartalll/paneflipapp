import PaneFlipCore
import SwiftUI

/// The Settings window. Icon tabs in the toolbar, one concern per tab. The width is fixed; the height follows the
/// selected tab's content, so the window grows and shrinks as you switch tabs.
struct SettingsView: View {
    let repository: LayoutRepository
    let layouts: LayoutManaging
    let editor: LayoutEditing
    let apps: LayoutAppsEditing
    let screens: ScreenProviding
    let refresh: () -> Void
    let settings: AppSettings
    let launchAtLogin: LaunchAtLoginModel
    let relauncher: AppRelaunching
    let updates: UpdatesModel
    let activation: ActivationPolicyControlling
    @Bindable var navigation: SettingsNavigation

    var body: some View {
        TabView(selection: $navigation.tab) {
            GeneralPane(settings: settings, launchAtLogin: launchAtLogin, relauncher: relauncher)
                .fixedSize(horizontal: false, vertical: true)
                .tabItem { Label("General", systemImage: "gearshape") }
                .tag(SettingsTab.general)

            LayoutsPane(repository: repository, layouts: layouts, editor: editor, apps: apps, screens: screens,
                        refresh: refresh, settings: settings, navigation: navigation)
                .fixedSize(horizontal: false, vertical: true)
                .tabItem { Label("Layouts", systemImage: "rectangle.split.2x2") }
                .tag(SettingsTab.layouts)

            StackingPane(settings: settings)
                .fixedSize(horizontal: false, vertical: true)
                .tabItem { Label("Stacking", systemImage: "square.stack.3d.up") }
                .tag(SettingsTab.stacking)

            ShortcutsPane(settings: settings)
                .fixedSize(horizontal: false, vertical: true)
                .tabItem { Label("Shortcuts", systemImage: "command") }
                .tag(SettingsTab.shortcuts)

            UpdatesPane(model: updates)
                .fixedSize(horizontal: false, vertical: true)
                .tabItem { Label("Updates", systemImage: "arrow.triangle.2.circlepath") }
                .tag(SettingsTab.updates)
        }
        .scenePadding()
        .frame(width: 640)
        .background(FixedWindowTitle(title: String(localized: "Settings")))
        .background(WindowPresenceReporter(activation: activation, level: .floating, minimizable: true))
        .onAppear { NSApp.activate(ignoringOtherApps: true) }
    }
}
