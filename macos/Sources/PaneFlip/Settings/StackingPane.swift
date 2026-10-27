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
        }
        .formStyle(.grouped)
    }
}
