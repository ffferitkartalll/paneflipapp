import SwiftUI

/// A row of the window carousel. It reads the card the mouse carries itself, so only this small body runs for each move
/// and the cards (built by the parent, which does not read it) are laid out again, not rebuilt.
struct IslandShiftedRow<Content: View>: View {
    let model: MenuBarIslandModel
    let size: CGSize
    @ViewBuilder let content: Content

    var body: some View {
        IslandCardsLayout(wide: size.width, fit: model.windowsSpan, height: size.height, carried: model.carried, carriedX: model.carriedX, shift: model.rowShift) { content }
    }
}
