import PaneFlipCore
import SwiftUI

/// Tab: the layouts of every screen and the geometry options that shape their zones.
struct LayoutsPane: View {
    let repository: LayoutRepository
    let layouts: LayoutManaging
    let editor: LayoutEditing
    let screens: ScreenProviding
    let refresh: () -> Void
    @Bindable var settings: AppSettings

    var body: some View {
        Form {
            ForEach(screens.screens()) { screen in
                ScreenLayoutsSection(screen: screen, repository: repository, layouts: layouts, editor: editor)
            }

            Section("Zones") {
                SliderSettingRow(title: "Gap between zones",
                                 detail: "Applies between zones only, never at screen edges.",
                                 value: $settings.gap, range: AppSettings.gapRange, step: AppSettings.gapStep) { editing in
                    if !editing { refresh() }
                }
                SliderSettingRow(title: "Minimum zone size",
                                 detail: "The layout editor won't split or resize a zone below this.",
                                 value: $settings.minZoneSize, range: AppSettings.minZoneSizeRange,
                                 step: AppSettings.minZoneSizeStep)
            }
            .disabled(!settings.placementEnabled)
        }
        .formStyle(.grouped)
    }
}
