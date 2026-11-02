import AppKit
import PaneFlipCore
import SwiftUI

/// The apps of one layout: for each zone, the apps that open in it and the order the island shows them in.
struct LayoutAppsView: View {
    let layout: NamedLayout
    let editor: LayoutAppsEditing
    /// The zone to scroll to and frame; a new request shows it again, also while the sheet is open.
    let focus: OrderingTarget?
    /// Chosen by the layout card, which knows the screen: the default zone and how to change it.
    /// Whether the zones beyond the screen's edges are in use.
    let showsOverflow: Bool
    let defaultZone: UUID?
    let setDefaultZone: (UUID) -> Void
    let setStartApp: (_ bundleID: String, _ chosen: Bool) -> Void
    let setZoneName: (_ zone: UUID, _ name: String) -> Void
    @Environment(\.dismiss) private var dismiss
    /// The zone whose apps are framed for a moment after the sheet opened on it.
    @State private var highlighted: UUID?
    @State private var highlightRequest: UUID?
    /// The zone being renamed, and the name typed so far.
    @State private var renamingZone: UUID?
    @State private var zoneNameDraft = ""

    /// Every zone, in the order across the strip: beyond the left edge, the screen, beyond the right edge.
    private var zones: [UUID] { showsOverflow ? layout.strip.zoneIDs : layout.root.leafIDs }
    /// The zones a default can be: those of the screen (the others are out of sight).
    private var screenZones: [UUID] { layout.root.leafIDs }
    private func name(_ zone: UUID) -> String { ZoneLabel.text(of: zone, in: layout.strip) }
    /// "Zone 1", with the name the user gave it after a dot.
    private func title(_ zone: UUID) -> Text {
        let number = String(localized: "Zone \(name(zone))")
        return Text(verbatim: layout.zoneNames[zone].map { "\(number) · \($0)" } ?? number)
    }

    var body: some View {
        let entries = editor.entries(inZones: zones)
        VStack(alignment: .leading, spacing: 12) {
            Text(verbatim: layout.name).font(.title3.bold())
            Text("An app opens in the zone you choose for it. Apps of a zone appear in the island in the order shown here; drag them by the handle to change it.")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                Picker("Default zone", selection: Binding(get: { defaultZone ?? screenZones.first ?? UUID() },
                                                          set: { setDefaultZone($0) })) {
                    ForEach(screenZones, id: \.self) { zone in
                        title(zone).tag(zone)
                    }
                }
                .fixedSize()
            }
            ScrollViewReader { proxy in
            Form {
                ForEach(zones, id: \.self) { zone in
                    Section {
                        ZoneAppsList(entries: entries.filter { $0.zoneID == zone }, zones: zones, title: title, editor: editor, startApps: layout.startApps, setStartApp: setStartApp)
                            .overlay {
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(AppAccent.color, lineWidth: 2)
                                    .padding(-6)
                                    .opacity(highlighted == zone ? 1 : 0)
                            }
                        addMenu(to: zone)
                    } header: {
                        HStack(spacing: 6) {
                            title(zone)
                            Button {
                                zoneNameDraft = layout.zoneNames[zone] ?? ""
                                renamingZone = zone
                            } label: { Image(systemName: "pencil") }
                                .buttonStyle(.borderless)
                                .help("Rename Zone")
                        }
                    }
                    .id(zone)
                }
            }
            .formStyle(.grouped)
            // The grouped form insets its cards by about 20 pt on each side: the sheet's own padding is enough, so the cards line
            // up with the text above them.
            .padding(.horizontal, -20)
            .alert("Rename Zone", isPresented: Binding(get: { renamingZone != nil }, set: { if !$0 { renamingZone = nil } })) {
                TextField("Zone name", text: $zoneNameDraft)
                Button("Done") { if let zone = renamingZone { setZoneName(zone, zoneNameDraft) } }
                Button("Cancel", role: .cancel) {}
            }
            .onAppear { reveal(focus, proxy) }
            .onChange(of: focus) { _, new in reveal(new, proxy) }
            }
            HStack {
                Button { editor.open(apps: editor.startApps(of: layout)) } label: {
                    Label("Open selected apps", systemImage: "play")
                }
                .disabled(editor.startApps(of: layout).isEmpty)
                Spacer()
                Button("Done") { dismiss() }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 520, height: 520)
    }

    private func reveal(_ target: OrderingTarget?, _ proxy: ScrollViewProxy) {
        guard let target, let zone = target.zoneID else { return }
        highlighted = zone
        highlightRequest = target.request
        DispatchQueue.main.async { withAnimation { proxy.scrollTo(zone, anchor: .top) } }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            if highlightRequest == target.request { withAnimation { highlighted = nil } }
        }
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
