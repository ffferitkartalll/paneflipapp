import PaneFlipCore
import SwiftUI

/// Tab: stacking several apps in one zone and how the pill that switches between them looks.
struct StackingPane: View {
    @Bindable var settings: AppSettings

    var body: some View {
        Form {
            Section("Stacking") {
                SettingRow(title: "Stack apps in a zone",
                           detail: "Several apps share a zone and you switch between them with the pill. When off, a zone holds one app and a new one replaces it.") {
                    Toggle("Stack apps in a zone", isOn: $settings.values.stackingEnabled).labelsHidden()
                }
            }
            .disabled(!settings.values.placementEnabled)

            Section("Pill") {
                SettingRow(title: "Show for each window",
                           detail: "What each segment of the pill shows. Double-tap Left Shift to hide the pill while the pointer is over it.") {
                    Picker("Show for each window", selection: $settings.values.pillContent) {
                        ForEach(PillContent.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }
            }
            .disabled(!settings.values.placementEnabled || !settings.values.stackingEnabled)
        }
        .formStyle(.grouped)
    }
}
