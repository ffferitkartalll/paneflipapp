import CoreGraphics

/// The cards of a row of windows that slides through a frame: the card in front is `wide`, the others lie against it on both sides with no gap, as wide
/// as the frame is; the row goes on past the room it is shown in.
/// `at` is the place of the card in front in cards (between two while it slides); nil when none is in front (the cards are centred).
public struct CarouselCards {
    public let count: Int
    public let wide: CGFloat

    public init(count: Int, wide: CGFloat) {
        self.count = count
        self.wide = wide
    }

    /// The width of each card that is not in front: the width of the frame.
    public var other: CGFloat { wide }

    /// A card widens as the front comes to it, and narrows as the front leaves it.
    public func width(of card: Int, at: CGFloat?, other: CGFloat) -> CGFloat {
        guard let at else { return other }
        return other + (wide - other) * max(0, 1 - abs(CGFloat(card) - at))
    }

    /// The middle of each card from the middle of the frame: the front card's is 0, or, with `focus`, the place of the card that is put in the middle instead
    /// (the row does not move when the front card is carried to another place among the others).
    public func centres(at: CGFloat?, other: CGFloat, focus: CGFloat? = nil) -> [CGFloat] {
        guard count > 0 else { return [] }
        var x: CGFloat = 0
        let middles = (0 ..< count).map { card -> CGFloat in
            let w = width(of: card, at: at, other: other)
            defer { x += w }
            return x + w / 2
        }
        guard let place = focus ?? at else { return middles.map { $0 - x / 2 } }
        let low = min(max(Int(place.rounded(.down)), 0), count - 1), high = min(low + 1, count - 1)
        let middle = middles[low] + (middles[high] - middles[low]) * min(max(place - CGFloat(low), 0), 1)
        return middles.map { $0 - middle }
    }

    /// The card under a point `x` from the middle of the frame.
    public func card(atX x: CGFloat, at: CGFloat?, other: CGFloat, focus: CGFloat? = nil) -> Int? {
        let middles = centres(at: at, other: other, focus: focus)
        return middles.indices.first { abs(x - middles[$0]) <= width(of: $0, at: at, other: other) / 2 }
    }
}
