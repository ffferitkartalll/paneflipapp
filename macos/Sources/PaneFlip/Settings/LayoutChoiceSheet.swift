import PaneFlipCore
import SwiftUI

/// The layouts of a display as pictures; a click on one chooses it, a right click shows the apps of the scene in it.
struct LayoutChoiceSheet: View {
    let screen: ScreenInfo
    let pictureWidth: CGFloat
    let layouts: [NamedLayout]
    let selected: UUID?
    let inUse: Set<UUID>
    let apps: LayoutAppsEditing
    let onChoose: (UUID) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modalRoom) private var room
    /// The layout whose apps are shown (a right click on it).
    @State private var showing: NamedLayout?

    private static let spacing: CGFloat = 14
    /// The room round the content, and how far inside this sheet the sheet of a layout's apps lies.
    private static let padding: CGFloat = 20
    /// All the room there is: the whole content area of the window it opens over.
    private var size: CGSize { room }
    /// The pictures fill the width of the sheet in as many columns as fit (see `PictureGrid`), from the display's size on the desk map.
    private var grid: PictureGrid { PictureGrid(width: size.width - 46, wanted: pictureWidth, spacing: Self.spacing) }
    private var picture: CGFloat { grid.picture }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(verbatim: screen.name).font(.title2.bold())
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(picture), spacing: Self.spacing), count: grid.columns), alignment: .leading, spacing: Self.spacing) {
                    ForEach(layouts) { layout in
                        Button {
                            onChoose(layout.id)
                            dismiss()
                        } label: {
                            VStack(spacing: 4) {
                                LayoutMiniature(root: layout.root, screenSize: screen.size, width: picture)
                                    .overlay { RoundedRectangle(cornerRadius: 8).strokeBorder(layout.id == selected ? AppAccent.color : .clear, lineWidth: 2) }
                                    .hoverHighlight(radius: 8)
                                Text(verbatim: layout.title(in: layouts)).font(.caption).lineLimit(1)
                            }
                        }
                        .buttonStyle(.plain)
                        .onRightClick { showing = layout }
                    }
                }
                .padding(2)
            }
            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
        }
        .padding(Self.padding)
        .frame(width: size.width, height: size.height)
        .background(NestedSheetPlacement(inset: Self.padding))
        .sheet(item: $showing) {
            LayoutAppsView(layout: $0, title: $0.title(in: layouts), canReset: !inUse.contains($0.id), editor: apps)
                .environment(\.modalRoom, CGSize(width: size.width - 2 * Self.padding, height: size.height - 2 * Self.padding))   // the room inside this sheet
        }
    }
}
