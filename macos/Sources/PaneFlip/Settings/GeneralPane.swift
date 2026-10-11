import PaneFlipCore
import SwiftUI

/// Tab: how the app starts and whether it is doing anything at all.
struct GeneralPane: View {
    @Bindable var settings: AppSettings
    let launchAtLogin: LaunchAtLoginModel

    var body: some View {
        Form {
            Section("Startup") {
                SettingRow(title: "Launch at login",
                           detail: launchDetail) {
                    Toggle("Launch at login", isOn: Binding(get: { launchAtLogin.isOn }, set: { launchAtLogin.setOn($0) }))
                        .labelsHidden()
                }
            }

            Section("Activity") {
                SettingRow(title: "Enable",
                           detail: "Turn all features on or off without quitting the app. When off, windows are left alone and no pills are shown.") {
                    Toggle("Enable", isOn: $settings.values.placementEnabled).labelsHidden()
                }
            }
        }
        .formStyle(.grouped)
        .onAppear { launchAtLogin.refresh() }
    }

    /// The explanation doubles as the place where a problem or a pending approval is reported.
    private var launchDetail: LocalizedStringKey {
        if let error = launchAtLogin.errorMessage { return "Couldn't change this: \(error)" }
        if launchAtLogin.status == .requiresApproval {
            return "Waiting for your approval in System Settings ▸ General ▸ Login Items."
        }
        return "Open PaneFlip automatically when you log in to your Mac."
    }
}
