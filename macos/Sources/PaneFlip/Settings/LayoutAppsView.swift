import AppKit
import PaneFlipCore
import SwiftUI

/// The apps of one layout: for each zone, the apps that open in it and the order the pill shows them in.
struct LayoutAppsView: View {
    let layout: NamedLayout
    let editor: LayoutAppsEditing
    @Environment(\.dismiss) private var dismiss

    private var zones: [UUID] { layout.root.leafIDs }

    var body: some View {
        let entries = editor.entries(inZones: zones)
        VStack(alignment: .leading, spacing: 12) {
            Text(verbatim: layout.name).font(.title3.bold())
            Text("An app opens in the zone you choose for it. Apps of a zone appear in the pill in the order shown here.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Form {
                ForEach(Array(zones.enumerated()), id: \.element) { index, zone in
                    let inZone = entries.filter { $0.zoneID == zone }
                    Section {
                        ForEach(Array(inZone.enumerated()), id: \.element.id) { position, entry in
                            row(entry, isFirst: position == 0, isLast: position == inZone.count - 1)
                        }
                        addMenu(to: zone)
                    } header: {
                        Text("Zone \(index + 1)")
                    }
                }
            }
            .formStyle(.grouped)
            HStack {
                Spacer()
                Button("Done") { dismiss() }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 520, height: 520)
    }

    private func row(_ entry: LayoutAppEntry, isFirst: Bool, isLast: Bool) -> some View {
        HStack(spacing: 8) {
            if let icon = entry.icon { Image(nsImage: icon).resizable().frame(width: 20, height: 20) }
            VStack(alignment: .leading, spacing: 1) {
                Text(verbatim: entry.name)
                if !entry.title.isEmpty {
                    Text(verbatim: entry.title).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            Spacer()
            Button { editor.reorder(slot: entry.slot, by: -1, inZones: zones) } label: { Image(systemName: "chevron.up") }
                .disabled(isFirst)
                .help("Show earlier in the pill")
            Button { editor.reorder(slot: entry.slot, by: 1, inZones: zones) } label: { Image(systemName: "chevron.down") }
                .disabled(isLast)
                .help("Show later in the pill")
            Menu {
                ForEach(Array(zones.enumerated()), id: \.element) { index, zone in
                    Button("Zone \(index + 1)") { editor.move(slot: entry.slot, to: zone, inZones: zones) }
                        .disabled(zone == entry.zoneID)
                }
            } label: { Image(systemName: "rectangle.split.2x2") }
                .menuIndicator(.hidden)
                .fixedSize()
                .help("Move to another zone")
            Button(role: .destructive) { editor.remove(slot: entry.slot) } label: { Image(systemName: "minus.circle") }
                .help("Remove")
        }
        .buttonStyle(.borderless)
    }

    private func addMenu(to zone: UUID) -> some View {
        Menu("Add app") {
            ForEach(editor.runningApps(), id: \.bundleID) { app in
                Button { editor.addApp(bundleID: app.bundleID, to: zone) } label: { Text(verbatim: app.name) }
            }
            Divider()
            Button("Other…") { chooseApp(for: zone) }
        }
        .menuIndicator(.hidden)
        .fixedSize()
    }

    /// Any installed app, not only the running ones.
    private func chooseApp(for zone: UUID) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        guard panel.runModal() == .OK, let url = panel.url, let id = Bundle(url: url)?.bundleIdentifier else { return }
        editor.addApp(bundleID: id, to: zone)
    }
}
