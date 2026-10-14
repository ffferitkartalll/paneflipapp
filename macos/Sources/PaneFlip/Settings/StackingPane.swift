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
                           detail: "What each segment of the pill shows. Use the button beside the pill or double-tap the hide key (see Shortcuts) to hide it while the pointer is over it.",
                           controlBelow: true) {
                    FullWidthSegments(selection: $settings.values.pillContent,
                                      options: PillContent.allCases.map { ($0, $0.title) })
                        .accessibilityLabel("Show for each window")
                }
                SettingRow(title: "Fetch brand icons",
                           detail: "Looks up an icon for apps the system has none for. The names of the apps in your zones are sent to a public icon host (jsDelivr). When off, nothing is looked up: icons already downloaded stay and other apps use a shape from their own icon.") {
                    Toggle("Fetch brand icons", isOn: $settings.values.fetchBrandIcons).labelsHidden()
                }
            }
            .disabled(!settings.values.placementEnabled || !settings.values.stackingEnabled)
        }
        .formStyle(.grouped)
    }
}
