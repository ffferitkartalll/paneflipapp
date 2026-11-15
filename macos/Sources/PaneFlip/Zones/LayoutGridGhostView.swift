import Foundation
import SwiftUI

/// The card the mouse carries over the grid of a whole layout: the card of a zone's grid itself (`ZoneWindowsCard`), lifted a little as it is there. Its picture is for places of
/// about its own shape; in one of another shape it shows the glyph of its app, as the card of a window that is not open does (`LayoutGridGhost.showsPicture`).
struct LayoutGridGhostView: View {
    let ghost: LayoutGridGhost
    var body: some View {
        ZoneWindowsCard(model: ghost.model, card: ghost.card, size: ghost.size, showsPicture: ghost.showsPicture)
            .scaleEffect(ghost.lifted ? 1.04 : 1)
            .position(ghost.at)
            .allowsHitTesting(false)
    }
}
