import Foundation
import SwiftUI

/// The card the mouse carries over the grid of a whole layout: the card of a zone's grid itself (`ZoneWindowsCard`), lifted a little as it is there. Its picture is for places of
/// about its own shape; in one of another shape it shows the glyph of its app, as the card of a window that is not open does (`LayoutGridGhost.showsPicture`).
struct LayoutGridGhostView: View {
    let ghost: LayoutGridGhost
    /// The card grows to its lifted size as it is taken up, not at once.
    @State private var taken = false
    var body: some View {
        ZoneWindowsCard(model: ghost.model, card: ghost.card, size: ghost.size, showsPicture: ghost.showsPicture)
            .scaleEffect(taken && ghost.lifted ? 1.04 : 1)
            .animation(.easeOut(duration: 0.15), value: taken && ghost.lifted)
            .position(ghost.at)
            .allowsHitTesting(false)
            .onAppear { taken = true }
    }
}
