import AppKit
import PaneFlipCore
import SwiftUI

/// The menu bar menu: the app's name, the on/off switch, the layout switcher, Settings and Quit, each group set apart by a divider.
struct MenuContent: View {
    let repository: LayoutRepository
    let layouts: LayoutManaging
    let screens: ScreenProviding
    @Bindable var settings: AppSettings
    let apps: LayoutAppsEditing
    let editor: LayoutEditing

    /// An empty picture the size of an icon: an item without an icon keeps its text where the others have theirs.
    private static var emptyIcon: Image { Image(nsImage: NSImage(size: NSSize(width: 13, height: 13))) }

    var body: some View {
        Button {} label: { Label { Text("PaneFlip") } icon: { Self.emptyIcon } }
            .labelStyle(.titleAndIcon)
            .disabled(true)
        // A button that draws its own tick: the system's tick sits in a column of its own, beside the icons of the other items.
        Button { settings.values.placementEnabled.toggle() } label: {
            Label { Text("Enable") } icon: {
                if settings.values.placementEnabled { Image(systemName: "checkmark") } else { Self.emptyIcon }
            }
        }
        .labelStyle(.titleAndIcon)
        .accessibilityAddTraits(settings.values.placementEnabled ? .isSelected : [])
        Divider()
        MenuLayouts(repository: repository, layouts: layouts, screens: screens)
        let toStart = screens.screens().compactMap { repository.activeLayout(for: $0.key) }.flatMap { apps.startApps(of: $0) }
        Button { editor.toggleAtPointer() } label: { Label("Edit layout", systemImage: "square.split.2x2") }
            .labelStyle(.titleAndIcon)
        Button { apps.open(apps: toStart) } label: { Label("Open selected apps", systemImage: "play") }
            .labelStyle(.titleAndIcon)
            .disabled(toStart.isEmpty)
        SettingsLink { Label("Settings", systemImage: "gearshape") }
        Divider()
        Button { NSApp.terminate(nil) } label: { Label("Quit", systemImage: "power") }
            .labelStyle(.titleAndIcon)
    }
}
