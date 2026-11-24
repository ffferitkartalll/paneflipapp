import SwiftUI

/// Takes a card from over its window to its cell as the grid opens (and back): scaled to the window's shape and size at first, then to the cell's. `ZoneWindowsModel.appear` is read
/// here, so that at every step of the slide only this small body is worked out, not the whole grid of the zone.
struct CardGlide: ViewModifier {
    let model: ZoneWindowsModel
    let cell: CGRect
    /// Where the window stands (in the zone); none for a card with no window: it comes into being in its cell, fading in.
    let from: CGRect?
    let carried: Bool
    /// The grid of the whole layout draws a card it carries itself.
    let hidden: Bool

    func body(content: Content) -> some View {
        let appear = model.appear, size = cell.size
        let start = from.map { CGPoint(x: $0.midX, y: $0.midY) } ?? CGPoint(x: cell.midX, y: cell.midY)
        // The card is scaled to the window's shape and size at first (not alike along both sides: a card is not quite the shape of the zone).
        let startScale = CGSize(width: from.map { size.width > 0 ? $0.width / size.width : 1 } ?? 1, height: from.map { size.height > 0 ? $0.height / size.height : 1 } ?? 1)
        let place = CGPoint(x: start.x + (cell.midX - start.x) * appear, y: start.y + (cell.midY - start.y) * appear)
        content
            .scaleEffect(x: carried ? 1.04 : startScale.width + (1 - startScale.width) * appear, y: carried ? 1.04 : startScale.height + (1 - startScale.height) * appear)
            .animation(.easeOut(duration: 0.15), value: carried)   // the card grows as it is taken up, not at once
            .opacity(hidden ? 0 : (from == nil ? appear : 1))
            // Placed in its cell once, moved from there by an offset: `position` would be laid out again for every card at every step of the slide, an offset is only drawn.
            .position(x: cell.midX, y: cell.midY)
            .offset(x: (carried ? model.carriedAt.x : place.x) - cell.midX, y: (carried ? model.carriedAt.y : place.y) - cell.midY)
    }
}
