import PaneFlipCore
import SwiftUI

/// One layout of a screen: its miniature with its buttons over it while the pointer is on it (as the cards of the island's windows row have them), and its name with Rename.
struct LayoutCard: View {
    let screen: ScreenInfo
    /// How wide the display is drawn on the desk map: the width of the card.
    let pictureWidth: CGFloat
    let layout: NamedLayout
    /// The name the layout has until it is renamed.
    var defaultTitle = ""
    /// The default layout of its display: it cannot be renamed or removed, only reset.
    var isDefault = false
    let layouts: LayoutManaging
    let editor: LayoutEditing

    @State private var isRenaming = false
    @State private var draftName = ""
    @State private var exporting = false
    @State private var confirmingRemoval = false
    @State private var offeringReset = false
    @State private var previewing = false
    @State private var hovered = false
    @State private var hoveredButton: String?

    private static let margin: CGFloat = 4

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            miniature
            nameRow
        }
        .frame(width: pictureWidth)
        .fileExporter(isPresented: $exporting, document: LayoutFile(data: (try? layout.exported()) ?? Data()),
                      contentType: .json, defaultFilename: title) { _ in }
        .alert("Rename Layout", isPresented: $isRenaming) {
            TextField(defaultTitle, text: $draftName)
            Button("Done", action: commitRename)
            if !layout.name.isEmpty {
                Button("Back to the default name (\(defaultTitle))") { layouts.rename(key: screen.key, id: layout.id, to: "") }
            }
            Button("Cancel", role: .cancel) {}
        }
        .alert("The default layout cannot be removed. Reset it instead?", isPresented: $offeringReset) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) { layouts.resetLayout(key: screen.key, id: layout.id) }
        }
        .confirmationDialog("Remove this layout?", isPresented: $confirmingRemoval, titleVisibility: .visible) {
            Button("Remove", role: .destructive) { layouts.removeLayout(key: screen.key, id: layout.id) }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var title: String { layout.name.isEmpty ? defaultTitle : layout.name }

    // MARK: Parts

    private var miniature: some View {
        // A click anywhere on the picture opens it large, with the areas beyond the screen's edges; the buttons lie over it.
        ZStack(alignment: .topLeading) {
            LayoutMiniature(root: layout.root, screenSize: screen.size, width: pictureWidth)
                .overlay { RoundedRectangle(cornerRadius: 8, style: .continuous).fill(.primary.opacity(hovered ? 0.1 : 0)).allowsHitTesting(false) }   // lit while the pointer is on the card, its buttons too
                .animation(.easeOut(duration: 0.1), value: hovered)
                .onTapGesture { previewing = true }
                .help("Preview")
                .accessibilityLabel("Preview")
                .accessibilityAddTraits(.isButton)
            buttons
        }
        .onHover { hovered = $0 }
        .sheet(isPresented: $previewing) { LayoutPreviewSheet(screen: screen, layout: layout, title: title, pictureWidth: pictureWidth) }
    }

    private static let side: CGFloat = 20
    private var pictureHeight: CGFloat { pictureWidth * screen.size.height / max(screen.size.width, 1) }

    /// Duplicate in the top left corner, Remove in the top right one, Edit in the bottom left one, and Export in the bottom right one.
    private var buttons: some View {
        let left = Self.margin, right = pictureWidth - Self.margin - Self.side
        let top = Self.margin, bottom = pictureHeight - Self.margin - Self.side
        return ZStack(alignment: .topLeading) {
            button("remove", "trash", "Remove", x: right, y: top) { if isDefault { offeringReset = true } else { confirmingRemoval = true } }
            button("edit", "pencil", "Edit", x: left, y: bottom) { editor.edit(on: screen, layoutID: layout.id) }
            button("duplicate", "plus.square.on.square", "Duplicate", x: left, y: top) { layouts.duplicate(key: screen.key, id: layout.id) }
            button("export", "square.and.arrow.up", "Export…", x: right, y: bottom) { exporting = true }
        }
        .frame(width: pictureWidth, alignment: .topLeading)
        .opacity(hovered ? 1 : 0)
        .animation(.easeOut(duration: 0.12), value: hovered)
    }

    private func button(_ id: String, _ symbol: String, _ help: LocalizedStringKey, x: CGFloat, y: CGFloat, enabled: Bool = true, action: @escaping () -> Void) -> some View {
        let lit = hoveredButton == id && enabled
        return Image(systemName: symbol).resizable().scaledToFit().fontWeight(.bold).foregroundStyle(.white.opacity(enabled ? 1 : 0.5))
            .frame(width: Self.side * 0.5, height: Self.side * 0.5)
            .frame(width: Self.side, height: Self.side)
            .background(Circle().fill(.black.opacity(lit ? 0.85 : 0.6)))
            .contentShape(Circle())
            .onHover { hoveredButton = $0 ? id : (hoveredButton == id ? nil : hoveredButton) }
            .onTapGesture { if enabled { action() } }
            .help(help)
            .accessibilityLabel(help)
            .accessibilityAddTraits(.isButton)
            .offset(x: x, y: y)
    }

    private var nameRow: some View {
        HStack(spacing: 8) {
            Text(verbatim: title)
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)   // a long name wraps, never truncates
            if !isDefault {
                Button {
                    draftName = layout.name
                    isRenaming = true
                } label: { Image(systemName: "pencil") }
                    .controlSize(.small)
                    .hoverHighlight()
                    .help("Rename")
                    .accessibilityLabel("Rename")
            }
        }
    }

    // MARK: Actions

    private func commitRename() {
        let name = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        layouts.rename(key: screen.key, id: layout.id, to: name)
    }
}
