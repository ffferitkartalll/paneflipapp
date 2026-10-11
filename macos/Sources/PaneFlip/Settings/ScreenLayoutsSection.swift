import PaneFlipCore
import SwiftUI

/// One screen: its name and size, then its layouts as cards and the card for adding another.
struct ScreenLayoutsSection: View {
    let screen: ScreenInfo
    let repository: LayoutRepository
    let layouts: LayoutManaging
    let editor: LayoutEditing

    var body: some View {
        Section {
            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: 14) {
                    let activeID = repository.activeLayout(for: screen.key)?.id
                    ForEach(repository.layouts(for: screen.key)) { layout in
                        LayoutCard(screen: screen, layout: layout, isActive: layout.id == activeID,
                                   layouts: layouts, editor: editor)
                    }
                    addCard
                }
                .fixedSize(horizontal: false, vertical: true)   // the row is as tall as its tallest card
                .padding(.vertical, 6)
            }
            .scrollIndicators(.hidden)
        } header: {
            HStack {
                Label(screen.name, systemImage: "display")
                Text(verbatim: "\(Int(screen.size.width))×\(Int(screen.size.height))").foregroundStyle(.secondary)
                Spacer()
                Text("Current desktop").foregroundStyle(.secondary)
            }
        }
    }

    /// Built like a layout preview and exactly as large as a whole layout card (preview, name row, buttons).
    /// The size comes from an invisible real card, so it is the same with or without layouts, for any screen shape.
    private var addCard: some View {
        ZStack {
            LayoutCard(screen: screen, layout: NamedLayout(name: "Layout", root: .leaf(UUID())), isActive: false,
                       layouts: layouts, editor: editor)
                .hidden()

            Button { layouts.addLayout(for: screen.key) } label: {
                VStack(spacing: 8) {
                    Image(systemName: "plus").font(.system(size: 22, weight: .regular))
                    Text("Add layout").font(.headline)
                }
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.quaternary, in: .rect(cornerRadius: 8))
                .contentShape(.rect(cornerRadius: 8))
            }
            .buttonStyle(.plain)
        }
        .frame(width: LayoutCard.width)
    }
}
