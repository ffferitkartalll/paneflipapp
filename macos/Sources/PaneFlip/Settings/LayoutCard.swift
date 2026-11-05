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

    @State private var isRenaming = false
    @State private var draftName = ""
    @State private var exporting = false
    @State private var confirmingRemoval = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            miniature
            nameRow
            actionRow
            HStack(spacing: 6) {
                Button { layouts.duplicate(key: screen.key, id: layout.id) } label: { stretched("Duplicate") }
                Button { exporting = true } label: { stretched("Export…") }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .frame(width: Self.width)
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
            .overlay { RoundedRectangle(cornerRadius: 8).strokeBorder(isActive ? AppAccent.color : .clear, lineWidth: 2) }
    }

    private var nameRow: some View {
        HStack(spacing: 8) {
            Text(layout.name)
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)   // a long name wraps, never truncates
            Button {
                draftName = layout.name
                isRenaming = true
            } label: { Image(systemName: "pencil") }
                .controlSize(.small)
                .help("Rename")
                .accessibilityLabel("Rename")
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
            Button { confirmingRemoval = true } label: { stretched("Remove") }
                .buttonStyle(.bordered)
                .confirmationDialog("Remove this layout?", isPresented: $confirmingRemoval, titleVisibility: .visible) {
                    Button("Remove", role: .destructive) { layouts.removeLayout(key: screen.key, id: layout.id) }
                    Button("Cancel", role: .cancel) {}
                }
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
