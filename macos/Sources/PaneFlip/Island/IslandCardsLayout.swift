import PaneFlipCore
import SwiftUI

/// Lays the cards of the window row side by side with no gap, each as wide as the frame, the row centred. The frame of the front window moves along the row, not
/// the row through the frame. `carriedX` and `shift` are animatable: the card the mouse carries is where the mouse is, and goes to its place with the motion.
struct IslandCardsLayout: Layout {
    let wide: CGFloat
    let fit: CGFloat
    let height: CGFloat
    let carried: Int?
    var carriedX: CGFloat
    /// How far the row is moved from the middle (see `MenuBarIslandModel.rowShift`).
    var shift: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(carriedX, shift) }
        set { carriedX = newValue.first; shift = newValue.second }
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize { CGSize(width: fit, height: height) }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let cards = CarouselCards(count: subviews.count, wide: wide)
        for (card, middle) in cards.centres(at: nil, other: cards.other).enumerated() {
            subviews[card].place(at: CGPoint(x: bounds.midX + (card == carried ? carriedX : middle + shift), y: bounds.midY), anchor: .center,
                                 proposal: ProposedViewSize(width: wide, height: height))
        }
    }
}
