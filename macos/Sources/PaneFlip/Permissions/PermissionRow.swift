import SwiftUI

/// One permission: what it is for and either a checkmark or the button to grant it.
struct PermissionRow: View {
    let item: PermissionsModel.Item
    let onGrant: () -> Void
    let onOpenSettings: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: item.permission.symbol)
                .font(.system(size: 22))
                .frame(width: 36, height: 36)
                .foregroundStyle(AppAccent.color)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.permission.title).font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
                Text(item.permission.detail).font(.callout).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)   // wrap, never truncate
                if !item.granted {
                    Button("Open System Settings", action: onOpenSettings)
                        .buttonStyle(.link)
                        .font(.callout)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutPriority(1)

            if item.granted {
                Label("Granted", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .labelStyle(.titleAndIcon)
                    .fixedSize()
            } else {
                Button("Grant Access", action: onGrant)
                    .buttonStyle(.glass)
                    .fixedSize()
            }
        }
        .padding(14)
        .background(.quaternary.opacity(0.5), in: .rect(cornerRadius: 12))
    }
}
