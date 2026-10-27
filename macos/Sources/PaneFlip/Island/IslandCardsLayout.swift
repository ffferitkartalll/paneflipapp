import PaneFlipCore
import SwiftUI

/// Lays the cards of the window row side by side with no gap: the front one as wide as the frame, the others as `CarouselCards` makes them. `at`, `other`
/// and `carriedX` are animatable: as they change with the spring, every card is laid out again at each step of it, the titles under the pictures as much as the
/// pictures. The card the mouse carries is where the mouse is, and while one is carried (or a grey card stands for a window being dragged in) the front card keeps its width (`discrete`: it is the card at
/// `frontIndex`, not the place `at` is going to).
struct IslandCardsLayout: Layout {
    let wide: CGFloat
    let fit: CGFloat
    let height: CGFloat
    var at: CGFloat
    var other: CGFloat
    /// No card is in front (`at` means nothing).
    let hasFront: Bool
    /// The place held in the middle instead of the front card's.
    let focus: CGFloat?
    let carried: Int?
    var carriedX: CGFloat
    let discrete: Bool
    let frontIndex: Int?

    var animatableData: AnimatablePair<AnimatablePair<CGFloat, CGFloat>, CGFloat> {
        get { AnimatablePair(AnimatablePair(at, other), carriedX) }
        set { at = newValue.first.first; other = newValue.first.second; carriedX = newValue.second }
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize { CGSize(width: fit, height: height) }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let cards = CarouselCards(count: subviews.count, wide: wide, fit: fit)
        let front: CGFloat? = hasFront ? (discrete ? frontIndex.map { CGFloat($0) } ?? at : at) : nil
        let centres = cards.centres(at: front, other: other, focus: focus)
        for (card, middle) in centres.enumerated() {
            subviews[card].place(at: CGPoint(x: bounds.midX + (card == carried ? carriedX : middle), y: bounds.midY), anchor: .center,
                                 proposal: ProposedViewSize(width: cards.width(of: card, at: front, other: other), height: height))
        }
    }
}
