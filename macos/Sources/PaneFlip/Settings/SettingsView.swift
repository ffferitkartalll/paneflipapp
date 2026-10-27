import PaneFlipCore
import SwiftUI

/// The Settings window. Icon tabs in the toolbar, one concern per tab. The width is fixed; the height follows the
/// selected tab's content, so the window grows and shrinks as you switch tabs, up to `tallestWindow` (then the tab scrolls).
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
    let catalog: AppCatalog
    let updates: UpdatesModel
    let activation: ActivationPolicyControlling
    @Bindable var navigation: SettingsNavigation

    /// How tall each tab was measured to be, so that a tab is laid out the same way each time it is shown.
    @State private var naturalHeights: [SettingsTab: CGFloat] = [:]

    private func natural(_ tab: SettingsTab) -> Binding<CGFloat> {
        Binding(get: { naturalHeights[tab] ?? 0 }, set: { naturalHeights[tab] = $0 })
    }

    /// The tallest the window may be, in points.
    private static let tallestWindow: CGFloat = 800
    /// What the window has besides a tab's content: its title bar, the tabs in the toolbar and the padding.
    private static let chrome: CGFloat = 128

    /// The most a tab's content takes: what the tallest window leaves, and never more than the screen has room for. A tab that is taller scrolls.
    private var contentHeight: CGFloat {
        min(Self.tallestWindow - Self.chrome, max(360, (NSScreen.main?.visibleFrame.height ?? 900) - 160))
    }

    var body: some View {
        TabView(selection: $navigation.tab) {
            GeneralPane(settings: settings, launchAtLogin: launchAtLogin, relauncher: relauncher)
                .cappedHeight(contentHeight, natural: natural(.general))
                .tabItem { Label("General", systemImage: "gearshape") }
                .tag(SettingsTab.general)

            AppsPane(settings: settings, catalog: catalog, editor: apps)
                .cappedHeight(contentHeight, natural: natural(.apps))
                .tabItem { Label("Apps", systemImage: "app.dashed") }
                .tag(SettingsTab.apps)

            LayoutsPane(repository: repository, layouts: layouts, editor: editor, apps: apps, screens: screens,
                        settings: settings, navigation: navigation)
                .cappedHeight(contentHeight, natural: natural(.layouts))
                .tabItem { Label("Layouts", systemImage: "rectangle.split.2x2") }
                .tag(SettingsTab.layouts)

            ZonesPane(settings: settings, refresh: refresh)
                .cappedHeight(contentHeight, natural: natural(.zones))
                .tabItem { Label("Zones", systemImage: "rectangle.split.3x1") }
                .tag(SettingsTab.zones)

            StackingPane(settings: settings)
                .cappedHeight(contentHeight, natural: natural(.stacking))
                .tabItem { Label("Stacking", systemImage: "interface.window.stack") }
                .tag(SettingsTab.stacking)

            TrackpadPane(settings: settings)
                .cappedHeight(contentHeight, natural: natural(.trackpad))
                .tabItem { Label("Moving", systemImage: "appwindow.swipe.rectangle") }
                .tag(SettingsTab.trackpad)

            ShortcutsPane(settings: settings)
                .cappedHeight(contentHeight, natural: natural(.shortcuts))
                .tabItem { Label("Shortcuts", systemImage: "command") }
                .tag(SettingsTab.shortcuts)

            UpdatesPane(model: updates)
                .cappedHeight(contentHeight, natural: natural(.updates))
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
