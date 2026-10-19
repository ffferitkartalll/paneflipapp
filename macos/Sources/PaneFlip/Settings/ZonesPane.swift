import PaneFlipCore
import SwiftUI

/// Tab: how zones are laid out, and the zones beyond the screen's edges with the ways to scroll to them.
struct ZonesPane: View {
    @Bindable var settings: AppSettings
    let refresh: () -> Void

    var body: some View {
        Form {
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

            Section("Zones beyond the screen") {
                SettingRow(title: "Zones beyond the screen's edges",
                           detail: "Lets a layout have zones beyond the left and right edges of a screen. Reach them with the scroll shortcuts (see Shortcuts), or by resting the pointer at the screen's edge. Switched off, the editor does not show them and their apps move to the default zone of the screen.") {
                    Toggle("Zones beyond the screen's edges", isOn: $settings.values.overflowZonesEnabled).labelsHidden()
                }
            }
            .disabled(!settings.values.placementEnabled)
        }
        .formStyle(.grouped)
    }
}
