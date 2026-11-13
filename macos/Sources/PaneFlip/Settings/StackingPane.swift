import PaneFlipCore
import SwiftUI

/// Tab: the icons of the apps that stack in the zones.
struct StackingPane: View {
    @Bindable var settings: AppSettings

    var body: some View {
        Form {
            Section("Icons") {
                SettingRow(title: "Fetch brand icons",
                           detail: "Looks up an icon for apps the system has none for. The names of the apps in your zones are sent to a public icon host (jsDelivr). When off, nothing is looked up: icons already downloaded stay and other apps use a shape from their own icon.") {
                    Toggle("Fetch brand icons", isOn: $settings.values.fetchBrandIcons).labelsHidden()
                }
            }
            .disabled(!settings.values.placementEnabled)

            Section("Zone notch") {
                SettingRow(title: "Open the zone notch only on a click",
                           detail: "The notch of a zone opens into the row of its windows only when you click it, not when you switch the zone's windows. The notch still lights up when the pointer is on it.") {
                    Toggle("Open the zone notch only on a click", isOn: $settings.values.notchOpensOnClickOnly).labelsHidden()
                }
                SettingRow(title: "Light up the zone notch while windows switch",
                           detail: "While you switch a zone's windows and the pointer is not on its notch, the notch shows as it does with the pointer on it. When off, it stays closed.") {
                    Toggle("Light up the zone notch while windows switch", isOn: $settings.values.notchLiftsOnSwitch).labelsHidden()
                }
                .disabled(!settings.values.notchOpensOnClickOnly)
            }
            .disabled(!settings.values.placementEnabled)
        }
        .formStyle(.grouped)
    }
}
