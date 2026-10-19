import SwiftUI

/// Tab: whether a newer release exists, and how to get it.
struct UpdatesPane: View {
    let model: UpdatesModel
    @Environment(\.openURL) private var openURL

    var body: some View {
        Form {
            Section("Version") {
                SettingRow(title: "Installed version") { Text(verbatim: model.currentVersion).foregroundStyle(.secondary) }
                SettingRow(title: "Check for updates", detail: status) {
                    Button("Check now") { Task { await model.check() } }
                        .disabled(model.state == .checking)
                }
            }
            switch model.state {
            case .available:
                Section("Update") {
                    SettingRow(title: "Install the update", detail: "PaneFlip downloads the new version, replaces itself with it and starts again.") {
                        Button("Install") { Task { await model.install() } }
                    }
                }
            case .installing:
                Section("Update") {
                    SettingRow(title: "Install the update", detail: "Installing…") { ProgressView().controlSize(.small) }
                }
            case .installFailed(let release):
                Section("Update") {
                    SettingRow(title: "Install the update", detail: "The update could not be installed. Download it from the release page instead.") {
                        Button("Open release page") { openURL(release.page) }
                    }
                }
            default:
                EmptyView()
            }
        }
        .formStyle(.grouped)
    }

    private var status: LocalizedStringKey {
        switch model.state {
        case .idle: "Looks for a newer release on GitHub. Nothing is sent but the request itself."
        case .checking: "Checking…"
        case .upToDate: "PaneFlip is up to date."
        case .available(let release), .installing(let release), .installFailed(let release):
            "Version \(release.version.description) is available."
        case .failed: "Could not reach GitHub. Try again later."
        }
    }
}
