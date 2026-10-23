import PaneFlipCore
import SwiftUI

/// One layout of a screen: its miniature, its name with Rename, and Activate / Edit / Remove in three equal parts.
struct LayoutCard: View {
    static let width: CGFloat = 230

    let screen: ScreenInfo
    let layout: NamedLayout
    let isActive: Bool
    /// Another desktop of the display uses this layout.
    var isTaken = false
    let layouts: LayoutManaging
    let editor: LayoutEditing
    let apps: LayoutAppsEditing
    let navigation: SettingsNavigation
    let showsOverflow: Bool
    /// The gap of the settings, for a layout that has none of its own.
    let defaultGap: Double

    @State private var isRenaming = false
    @State private var draftName = ""
    @State private var exporting = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            miniature
            nameRow
            actionRow
            LayoutGapRow(layout: layout, defaultGap: defaultGap) { layouts.setGap(key: screen.key, id: layout.id, to: $0) }
            HStack(spacing: 6) {
                Button { navigation.ordering = OrderingTarget(layoutID: layout.id, zoneID: nil) } label: { stretched("Apps…") }
                Button { layouts.duplicate(key: screen.key, id: layout.id) } label: { stretched("Duplicate") }
                Button { exporting = true } label: { Image(systemName: "square.and.arrow.up") }
                    .help("Export…")
                    .accessibilityLabel("Export…")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .frame(width: Self.width)
        .sheet(isPresented: Binding(
            get: { navigation.ordering?.layoutID == layout.id },
            set: { if !$0 && navigation.ordering?.layoutID == layout.id { navigation.ordering = nil } })) {
            LayoutAppsView(layout: layout, editor: apps, focus: navigation.ordering, showsOverflow: showsOverflow, defaultZone: layout.fallbackZoneID,
                           setDefaultZone: { layouts.setDefaultZone(key: screen.key, id: layout.id, to: $0) },
                           setStartApp: { layouts.setStartApp(key: screen.key, id: layout.id, bundleID: $0, chosen: $1) },
                           setZoneName: { layouts.setZoneName(key: screen.key, id: layout.id, zone: $0, to: $1) })
        }
        .fileExporter(isPresented: $exporting, document: LayoutFile(data: (try? layout.exported()) ?? Data()),
                      contentType: .json, defaultFilename: layout.name) { _ in }
        .alert("Rename Layout", isPresented: $isRenaming) {
            TextField("Layout name", text: $draftName)
            Button("Done", action: commitRename)
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: Parts

    private var miniature: some View {
        LayoutMiniature(root: layout.root, screenSize: screen.size, width: Self.width)
            .overlay { RoundedRectangle(cornerRadius: 8).strokeBorder(isActive ? Color.accentColor : .clear, lineWidth: 2) }
    }

    private var nameRow: some View {
        HStack(spacing: 8) {
            Text(layout.name)
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)   // a long name wraps, never truncates
            Button("Rename") {
                draftName = layout.name
                isRenaming = true
            }
            .controlSize(.small)
        }
    }

    /// Three standard small buttons sharing the preview's width. Only the label is stretched (the bordered
    /// style wraps its label), so height and type size stay exactly those of any other small button.
    private var actionRow: some View {
        HStack(spacing: 6) {
            if isActive {
                // The active layout shows its state in the button's place: blue, reading "Active".
                Button { } label: { stretched("Active") }
                    .buttonStyle(.borderedProminent)
                    .allowsHitTesting(false)
            } else {
                Button { layouts.activate(key: screen.key, id: layout.id) } label: { stretched("Activate") }
                    .buttonStyle(.bordered)
                    .disabled(isTaken)
            }
            Button { editor.edit(on: screen, layoutID: layout.id) } label: { stretched("Edit") }
                .buttonStyle(.bordered)
            Button(role: .destructive) { layouts.removeLayout(key: screen.key, id: layout.id) } label: { stretched("Remove") }
                .buttonStyle(.bordered)
        }
        .controlSize(.small)
        .frame(width: Self.width)
    }

    private func stretched(_ title: LocalizedStringKey) -> some View {
        Text(title).frame(maxWidth: .infinity)
    }

    // MARK: Actions

    private func commitRename() {
        let name = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        layouts.rename(key: screen.key, id: layout.id, to: name)
    }
}
