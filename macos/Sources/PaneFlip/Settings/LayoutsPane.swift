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
    let refresh: () -> Void
    @Bindable var settings: AppSettings
    /// Bumped when displays are plugged in or out, so the list of screens is read again.
    @State private var displaysChanged = 0

    var body: some View {
        let _ = displaysChanged
        Form {
            ForEach(screens.screens()) { screen in
                ScreenLayoutsSection(screen: screen, repository: repository, layouts: layouts, editor: editor, apps: apps)
            }

            Section("Zones") {
                SliderSettingRow(title: "Gap between zones",
                                 detail: "Applies between zones only, never at screen edges.",
                                 value: $settings.values.gap, range: AppSettings.gapRange, step: AppSettings.gapStep) { editing in
                    if !editing { refresh() }
                }
                SliderSettingRow(title: "Minimum zone size",
                                 detail: "The layout editor won't split or resize a zone below this.",
                                 value: $settings.values.minZoneSize, range: AppSettings.minZoneSizeRange,
                                 step: AppSettings.minZoneSizeStep)
            }
            .disabled(!settings.values.placementEnabled)
        }
        .formStyle(.grouped)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)) { _ in
            displaysChanged += 1
        }
    }
}
