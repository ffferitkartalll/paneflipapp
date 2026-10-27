import PaneFlipCore
import SwiftUI

/// Lays the cards of the window row side by side with no gap: the front one as wide as the frame, the others as `CarouselCards` makes them. `at` and `other`
/// are animatable: as they change with the spring, the cards widen, narrow and slide with it.
struct IslandCardsLayout: Layout {
    let wide: CGFloat
    let fit: CGFloat
    let height: CGFloat
    var at: CGFloat
    var other: CGFloat
    /// No card is in front (`at` means nothing).
    let hasFront: Bool

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(at, other) }
        set { at = newValue.first; other = newValue.second }
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize { CGSize(width: fit, height: height) }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let cards = CarouselCards(count: subviews.count, wide: wide, fit: fit)
        let front = hasFront ? at : nil
        for (card, middle) in cards.centres(at: front, other: other).enumerated() {
            subviews[card].place(at: CGPoint(x: bounds.midX + middle, y: bounds.midY), anchor: .center,
                                 proposal: ProposedViewSize(width: cards.width(of: card, at: front, other: other), height: height))
        }
    }
}
