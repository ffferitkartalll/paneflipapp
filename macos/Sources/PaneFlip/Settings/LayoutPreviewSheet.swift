import PaneFlipCore
import SwiftUI

/// A layout drawn large with the areas beyond the screen's edges beside the screen.
struct LayoutPreviewSheet: View {
    let screen: ScreenInfo
    let layout: NamedLayout
    let title: String
    /// How wide the screen's own part is drawn (as large as the display is in the desk map).
    let pictureWidth: CGFloat
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modalRoom) private var room

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(verbatim: title).font(.title2.bold())
            LayoutMiniature(strip: layout.strip, screenSize: screen.size, width: totalWidth)
            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: max(totalWidth, 200) + 44)   // the picture, the padding and 2 pt to spare at each side: a picture filling the sheet to its edge is cut by a fraction of a point
    }

    /// The screen as large as in the desk map and the areas beside it at the same scale; smaller where the window it opens over has no room for it, in width or in height.
    private var totalWidth: CGFloat {
        let wanted = pictureWidth * CGFloat(layout.strip.totalWidth)
        let aspect = screen.size.width * CGFloat(layout.strip.totalWidth) / max(screen.size.height, 1)
        // 4 pt less than the room: the picture must not touch the sheet's edge, where a fraction of a point would cut it.
        return min(wanted, room.width - 44, (room.height - 140) * aspect)
    }
}
