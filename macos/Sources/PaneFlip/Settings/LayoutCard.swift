import PaneFlipCore
import SwiftUI

/// One layout of a screen: its miniature, its name with Rename, and Activate / Edit / Remove in three equal parts.
struct LayoutCard: View {
    static let width: CGFloat = 230

    let screen: ScreenInfo
    let layout: NamedLayout
    let isActive: Bool
    let layouts: LayoutManaging
    let editor: LayoutEditing
    let apps: LayoutAppsEditing
    let navigation: SettingsNavigation

    @State private var isRenaming = false
    @State private var draftName = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            miniature
            nameRow
            actionRow
            Button { navigation.ordering = OrderingTarget(layoutID: layout.id, zoneID: nil) } label: { stretched("Apps…") }
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
        .frame(width: Self.width)
        .sheet(isPresented: Binding(
            get: { navigation.ordering?.layoutID == layout.id },
            set: { if !$0 && navigation.ordering?.layoutID == layout.id { navigation.ordering = nil } })) {
            LayoutAppsView(layout: layout, editor: apps, focus: navigation.ordering, defaultZone: layout.fallbackZoneID,
                           setDefaultZone: { layouts.setDefaultZone(key: screen.key, id: layout.id, to: $0) })
        }
        .alert("Rename Layout", isPresented: $isRenaming) {
            TextField("Layout name", text: $draftName)
            Button("Rename", action: commitRename)
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: Parts

    private var miniature: some View {
        Canvas { gc, size in
            for (i, z) in layout.root.zones(in: CGRect(origin: .zero, size: size)).enumerated() {
                gc.stroke(Path(roundedRect: z.rect.insetBy(dx: 1, dy: 1), cornerRadius: 4), with: .color(.secondary))
                gc.draw(Text(verbatim: "\(i + 1)").font(.caption2).foregroundStyle(.secondary),
                        at: CGPoint(x: z.rect.minX + 9, y: z.rect.minY + 9))
            }
        }
        .aspectRatio(screen.size.width / screen.size.height, contentMode: .fit)
        .frame(width: Self.width)
        .background(.quaternary, in: .rect(cornerRadius: 8))
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
