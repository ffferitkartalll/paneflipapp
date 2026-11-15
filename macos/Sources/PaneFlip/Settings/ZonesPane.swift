import PaneFlipCore
import SwiftUI

/// Tab: how zones are laid out.
struct ZonesPane: View {
    @Bindable var settings: AppSettings

    var body: some View {
        Form {
            Section("Zones") {
                SettingRow(title: "Restore window size",
                           detail: "A window you drag out of its zone returns to the size it had before the zone took it in.") {
                    Toggle("Restore window size", isOn: $settings.values.restoreSizeOnLeave).labelsHidden()
                }
            }
            .disabled(!settings.values.placementEnabled)

            Section("Moving between zones") {
                SettingRow(title: "Move between zones with the keyboard",
                           detail: "The shortcuts in the Shortcuts tab move the focus to the zone above, to the left, below or to the right.") {
                    Toggle("Move between zones with the keyboard", isOn: $settings.values.zoneNavigationEnabled).labelsHidden()
                }
            }
            .disabled(!settings.values.placementEnabled)

            Section("Screens beyond the screen") {
                SettingRow(title: "Stop at the lines between zones",
                           detail: "Scrolling between the screens of a layout also stops at the edges of zones, not only at each screen.") {
                    Toggle("Stop at the lines between zones", isOn: $settings.values.scrollStopsAtZones).labelsHidden()
                }
            }
            .disabled(!settings.values.placementEnabled)
        }
        .formStyle(.grouped)
    }
}
