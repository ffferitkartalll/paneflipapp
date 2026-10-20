import PaneFlipCore
import SwiftUI

/// Tab: how scrolling with two fingers behaves while the scroll keys are held.
struct TrackpadPane: View {
    @Bindable var settings: AppSettings

    var body: some View {
        Form {
            Section {
                SliderSettingRow(title: "Trackpad speed",
                                 detail: "How far the content goes for the same stroke of two fingers when you scroll with the keys held. It also follows the tracking speed set for the system's trackpad.",
                                 value: $settings.values.trackpadSpeed, range: AppSettings.trackpadSpeedRange,
                                 step: AppSettings.trackpadSpeedStep, unit: "×")
            }
            .disabled(!settings.values.placementEnabled)
        }
        .formStyle(.grouped)
    }
}
