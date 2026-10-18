import AppKit
import SwiftUI

/// Tab: whether a newer release exists, and how to get it.
struct UpdatesPane: View {
    let model: UpdatesModel
    @Environment(\.openURL) private var openURL
    private static let upgradeCommand = "brew upgrade --cask paneflipapp"

    var body: some View {
        Form {
            Section("Version") {
                SettingRow(title: "Installed version") { Text(verbatim: model.currentVersion).foregroundStyle(.secondary) }
                SettingRow(title: "Check for updates", detail: status) {
                    Button("Check now") { Task { await model.check() } }
                        .disabled(model.state == .checking)
                }
            }
            if case .available(let release) = model.state {
                Section("Update") {
                    if model.installedWithHomebrew {
                        SettingRow(title: "Update with Homebrew",
                                   detail: "PaneFlip was installed with Homebrew. Run this command in Terminal, then open PaneFlip again.") {
                            Button("Copy command") {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(Self.upgradeCommand, forType: .string)
                            }
                        }
                        Text(verbatim: Self.upgradeCommand).font(.system(.body, design: .monospaced)).textSelection(.enabled)
                    } else {
                        SettingRow(title: "Download the update", detail: "Open the release page, download the disk image and replace PaneFlip in Applications.") {
                            Button("Open release page") { openURL(release.page) }
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    private var status: LocalizedStringKey {
        switch model.state {
        case .idle: "Looks for a newer release on GitHub. Nothing is sent but the request itself."
        case .checking: "Checking…"
        case .upToDate: "PaneFlip is up to date."
        case .available(let release): "Version \(release.version.description) is available."
        case .failed: "Could not reach GitHub. Try again later."
        }
    }
}
