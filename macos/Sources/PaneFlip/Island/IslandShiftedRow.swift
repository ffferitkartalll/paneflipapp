import SwiftUI

/// A row of the window carousel, moved sideways by the fingers. It reads the drag itself, so only this small body runs for each finger event
/// and the rows (built by the parent, which does not read the drag) are moved, not rebuilt.
struct IslandShiftedRow<Content: View>: View {
    let model: MenuBarIslandModel
    let size: CGSize
    let content: Content

    var body: some View {
        content.offset(x: (CGFloat(model.windows.count - 1) / 2 - (model.cardsAt ?? 0)) * size.width)
    }
}
