import PaneFlipCore
import SwiftUI

/// Tab: how zones are laid out, and the screens beyond the screen's edges with the ways to scroll to them.
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
                SettingRow(title: "Screens beyond the screen's edges",
                           detail: "Lets a layout have screens beyond the left and right edges of a screen. Reach them with the scroll shortcuts (see Shortcuts), or by scrolling over the island in the menu bar. Switched off, the editor does not show them and their apps move to the default zone of the screen.") {
                    Toggle("Screens beyond the screen's edges", isOn: $settings.values.overflowZonesEnabled).labelsHidden()
                }
            }
            .disabled(!settings.values.placementEnabled)
        }
        .formStyle(.grouped)
    }
}
