import CoreGraphics

/// The cards of a row of windows that slides through a frame: the card in front is `wide`, the others lie against it on both sides with no gap, as wide
/// as the frame is, or narrower, all alike, when they would not fit in `fit` (the room the row has, the front card in the middle of it).
/// `at` is the place of the card in front in cards (between two while it slides); nil when none is in front (the cards share the room and are centred).
public struct CarouselCards {
    public let count: Int
    public let wide: CGFloat
    public let fit: CGFloat

    public init(count: Int, wide: CGFloat, fit: CGFloat) {
        self.count = count
        self.wide = wide
        self.fit = max(fit, wide)
    }

    /// The width of each card that is not in front, with `front` the card in front (nil: none).
    public func other(front: Int?) -> CGFloat {
        guard count > 0 else { return wide }
        guard let front else { return min(wide, fit / CGFloat(count)) }
        let most = max(front, count - 1 - front)
        return most == 0 ? wide : min(wide, (fit - wide) / 2 / CGFloat(most))
    }

    /// A card widens as the front comes to it, and narrows as the front leaves it.
    public func width(of card: Int, at: CGFloat?, other: CGFloat) -> CGFloat {
        guard let at else { return other }
        return other + (wide - other) * max(0, 1 - abs(CGFloat(card) - at))
    }

    /// The middle of each card from the middle of the frame: the front card's is 0.
    public func centres(at: CGFloat?, other: CGFloat) -> [CGFloat] {
        guard count > 0 else { return [] }
        var x: CGFloat = 0
        let middles = (0 ..< count).map { card -> CGFloat in
            let w = width(of: card, at: at, other: other)
            defer { x += w }
            return x + w / 2
        }
        guard let at else { return middles.map { $0 - x / 2 } }
        let low = min(max(Int(at.rounded(.down)), 0), count - 1), high = min(low + 1, count - 1)
        let focus = middles[low] + (middles[high] - middles[low]) * min(max(at - CGFloat(low), 0), 1)
        return middles.map { $0 - focus }
    }

    /// The card under a point `x` from the middle of the frame.
    public func card(atX x: CGFloat, at: CGFloat?, other: CGFloat) -> Int? {
        let middles = centres(at: at, other: other)
        return middles.indices.first { abs(x - middles[$0]) <= width(of: $0, at: at, other: other) / 2 }
    }
}
