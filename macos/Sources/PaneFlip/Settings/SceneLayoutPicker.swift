import PaneFlipCore
import SwiftUI

/// One display of a scene: its name, the layout the scene uses on it as a picture with its name; a click opens the layouts to choose from.
struct SceneLayoutPicker: View {
    let screen: ScreenInfo
    /// The display's width on the desk map, for the sheet of layouts.
    let pictureWidth: CGFloat
    /// How wide it is drawn here, in the row of the displays.
    let shownWidth: CGFloat
    let layouts: [NamedLayout]
    let selected: UUID?
    /// The layouts the display shows now, on this desktop and on its others, while the scene is in use (none when it is not): a right click on them opens nothing, their apps are changed in the island and the grids.
    let inUse: Set<UUID>
    let apps: LayoutAppsEditing
    let onChoose: (UUID) -> Void

    @State private var choosing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(verbatim: screen.name).lineLimit(1).minimumScaleFactor(0.7).frame(width: shownWidth, alignment: .leading)
            if let used = layouts.first(where: { $0.id == selected }) {
                Button { choosing = true } label: {
                    VStack(spacing: 4) {
                        LayoutMiniature(root: used.root, screenSize: screen.size, width: shownWidth)
                            .overlay { RoundedRectangle(cornerRadius: 8).strokeBorder(AppAccent.color, lineWidth: 2) }
                            .hoverHighlight(radius: 8)
                        Text(verbatim: used.title(in: layouts)).font(.caption).lineLimit(1)
                    }
                    .frame(width: shownWidth)
                }
                .buttonStyle(.plain)
            }
        }
        .sheet(isPresented: $choosing) { LayoutChoiceSheet(screen: screen, pictureWidth: pictureWidth, layouts: layouts, selected: selected, inUse: inUse, apps: apps, onChoose: onChoose) }
    }
}
