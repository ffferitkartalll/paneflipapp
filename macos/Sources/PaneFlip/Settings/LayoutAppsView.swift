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
                            LayoutAppRow(entry: entry, zones: zones, editor: editor,
                                         isFirst: position == 0, isLast: position == inZone.count - 1)
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

/// One app of a zone: order, zone, removal, and (with several windows) the order of its windows.
private struct LayoutAppRow: View {
    let entry: LayoutAppEntry
    let zones: [UUID]
    let editor: LayoutAppsEditing
    let isFirst: Bool
    let isLast: Bool
    @State private var showsWindows = false

    var body: some View {
        HStack(spacing: 8) {
            if let icon = entry.icon { Image(nsImage: icon).resizable().frame(width: 20, height: 20) }
            VStack(alignment: .leading, spacing: 1) {
                Text(verbatim: entry.name)
                if entry.windows.count > 1 {
                    Text("\(entry.windows.count) windows").font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            if entry.windows.count > 1 {
                Button { showsWindows = true } label: { Image(systemName: "list.number") }
                    .help("Order of the windows")
                    .popover(isPresented: $showsWindows) { windowOrder }
            }
            Button { editor.reorder(app: entry.bundleID, in: entry.zoneID, by: -1, inZones: zones) } label: { Image(systemName: "chevron.up") }
                .disabled(isFirst)
                .help("Show earlier in the pill")
            Button { editor.reorder(app: entry.bundleID, in: entry.zoneID, by: 1, inZones: zones) } label: { Image(systemName: "chevron.down") }
                .disabled(isLast)
                .help("Show later in the pill")
            Menu {
                ForEach(Array(zones.enumerated()), id: \.element) { index, zone in
                    Button("Zone \(index + 1)") {
                        editor.move(app: entry.bundleID, from: entry.zoneID, to: zone, inZones: zones)
                    }
                    .disabled(zone == entry.zoneID)
                }
            } label: { Image(systemName: "rectangle.split.2x2") }
                .menuIndicator(.hidden)
                .fixedSize()
                .help("Move to another zone")
            Button(role: .destructive) { editor.remove(app: entry.bundleID, in: entry.zoneID, inZones: zones) } label: {
                Image(systemName: "minus.circle")
            }
            .help("Remove")
        }
        .buttonStyle(.borderless)
    }

    /// The windows of the app, in the order the pill shows them.
    private var windowOrder: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Order of the windows").font(.headline)
            ForEach(Array(entry.windows.enumerated()), id: \.element.id) { position, window in
                HStack(spacing: 8) {
                    Text(verbatim: window.title.isEmpty ? entry.name : window.title)
                        .lineLimit(1)
                        .frame(width: 260, alignment: .leading)
                    Spacer()
                    Button { editor.reorder(window: window.slot, by: -1, inZones: zones) } label: { Image(systemName: "chevron.up") }
                        .disabled(position == 0)
                    Button { editor.reorder(window: window.slot, by: 1, inZones: zones) } label: { Image(systemName: "chevron.down") }
                        .disabled(position == entry.windows.count - 1)
                }
            }
        }
        .buttonStyle(.borderless)
        .padding(14)
        .frame(width: 380)
    }
}
