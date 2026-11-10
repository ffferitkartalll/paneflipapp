import CoreGraphics

/// Cards side by side, each as wide as it asks: how they are made narrower to fit, and where the lit one stands in a row of them.
public enum CardRow {
    /// `widths` made to fit (`fits`; they fit the better the narrower they are): the widest made narrower, all to the same width, only as much as they must, each to
    /// its own `narrowest` at most (then they may still not fit).
    public static func narrowed(_ widths: [CGFloat], narrowest: [CGFloat], fits: ([CGFloat]) -> Bool) -> [CGFloat] {
        func at(_ width: CGFloat) -> [CGFloat] { zip(widths, narrowest).map { min($0, max(width, $1)) } }
        guard !fits(widths), let widest = widths.max(), let floor = narrowest.min(), widest > floor else { return widths }
        guard fits(at(floor)) else { return at(floor) }
        var low = floor, high = widest
        for _ in 0..<24 {
            let middle = (low + high) / 2
            if fits(at(middle)) { low = middle } else { high = middle }
        }
        return at(low)
    }

    /// Where the lit card stands in a row of cards of `widths`, from the row's left edge: on the card at `place`, or a share of the way from it to the next
    /// (while fingers lead), as wide as the two are between them. Not past the first or the last.
    public static func lit(at place: CGFloat, widths: [CGFloat]) -> (x: CGFloat, width: CGFloat) {
        guard !widths.isEmpty else { return (0, 0) }
        let place = min(max(place, 0), CGFloat(widths.count - 1)), index = Int(place), share = place - CGFloat(index)
        let next = widths[min(index + 1, widths.count - 1)]
        return (widths[..<index].reduce(0, +) + share * widths[index], widths[index] + share * (next - widths[index]))
    }

    /// The card at `x`, measured from the row's left edge (nil: outside the row).
    public static func index(atX x: CGFloat, widths: [CGFloat]) -> Int? {
        guard x >= 0 else { return nil }
        var edge: CGFloat = 0
        for (index, width) in widths.enumerated() {
            edge += width
            if x < edge { return index }
        }
        return nil
    }
}
