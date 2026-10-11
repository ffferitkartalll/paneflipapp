import SwiftUI

/// The first-run / permission-missing screen. Continue stays disabled until everything is granted.
struct PermissionsView: View {
    let model: PermissionsModel
    let onContinue: () -> Void
    let onQuit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text("PaneFlip needs your permission").font(.title2.bold())
                    .fixedSize(horizontal: false, vertical: true)
                Text("Grant the access below in System Settings. This window updates as soon as you do.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: 10) {
                ForEach(model.items) { item in
                    PermissionRow(item: item,
                                  onGrant: { model.request(item.permission) },
                                  onOpenSettings: { model.openSystemSettings(for: item.permission) })
                }
            }

            HStack {
                Button("Quit", action: onQuit)
                Spacer()
                Button("Continue", action: onContinue)
                    .buttonStyle(.glassProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!model.allGranted)
            }
        }
        .padding(24)
        .frame(width: 520)
        .fixedSize(horizontal: false, vertical: true)   // the window is as tall as its text needs
    }
}
