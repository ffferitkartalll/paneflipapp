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

    /// Whether the window is the key window. While it is not, what a tab shows is a picture of it: a live form in a window that no one works in costs the scrolls beyond the
    /// screen's edge frames (the app is busy with it at every frame), and the picture looks the same. The live form comes back as the window becomes key again.
    @State private var isKey = true
    @State private var frozen: NSImage?
    @State private var snapshots = PaneSnapshots()

    private func pane<Content: View>(_ tab: SettingsTab, @ViewBuilder _ content: () -> Content) -> some View {
        Group {
            if let frozen {
                Image(nsImage: frozen).frame(width: frozen.size.width, height: frozen.size.height)
            } else {
                content().background(PaneSnapshotAnchor(snapshots: snapshots))
            }
        }
        .cappedHeight(contentHeight, natural: natural(tab))
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
            pane(.general) { GeneralPane(settings: settings, launchAtLogin: launchAtLogin, relauncher: relauncher) }
                .tabItem { Label("General", systemImage: "gearshape") }
                .tag(SettingsTab.general)

            pane(.displays) { DisplaysPane(screens: screens, settings: settings) }
                .tabItem { Label("Displays", systemImage: "display.2") }
                .tag(SettingsTab.displays)

            pane(.layouts) { LayoutsPane(repository: repository, layouts: layouts, editor: editor, apps: apps, screens: screens,
                        settings: settings, navigation: navigation) }
                .tabItem { Label("Layouts", systemImage: "rectangle.split.2x2") }
                .tag(SettingsTab.layouts)

            pane(.zones) { ZonesPane(settings: settings, refresh: refresh) }
                .tabItem { Label("Zones", systemImage: "rectangle.split.3x1") }
                .tag(SettingsTab.zones)

            pane(.stacking) { StackingPane(settings: settings) }
                .tabItem { Label("Stacking", systemImage: "interface.window.stack") }
                .tag(SettingsTab.stacking)

            pane(.trackpad) { TrackpadPane(settings: settings) }
                .tabItem { Label("Moving", systemImage: "appwindow.swipe.rectangle") }
                .tag(SettingsTab.trackpad)

            pane(.shortcuts) { ShortcutsPane(settings: settings) }
                .tabItem { Label("Shortcuts", systemImage: "command") }
                .tag(SettingsTab.shortcuts)

            pane(.apps) { AppsPane(settings: settings, catalog: catalog, editor: apps) }
                .tabItem { Label("Apps", systemImage: "app.dashed") }
                .tag(SettingsTab.apps)

            pane(.updates) { UpdatesPane(model: updates) }
                .tabItem { Label("Updates", systemImage: "arrow.triangle.2.circlepath") }
                .tag(SettingsTab.updates)
        }
        .scenePadding()
        .frame(width: 640)
        .background(FixedWindowTitle(title: String(localized: "Settings")))
        .background(WindowPresenceReporter(activation: activation, level: .floating, minimizable: true, isKey: $isKey, identifier: SettingsContentKeeper.windowIdentifier))
        .onChange(of: isKey) { _, key in frozen = key ? nil : snapshots.image() }
        .onAppear { NSApp.activate(ignoringOtherApps: true) }
    }
}
