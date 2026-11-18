import CoreGraphics

extension PagedScroll {
    /// Where a row of cards `pitch` points apart, scrolled to `offset`, rests after one step (+1 toward the end, -1 toward the start): on the next card edge, never beyond the
    /// end of the row (`maxOffset`). A row that rests at its end, between two edges, goes back to the edge before it.
    public static func offset(after step: Int, from offset: CGFloat, pitch: CGFloat, maxOffset: CGFloat) -> CGFloat {
        guard pitch > 0, maxOffset > 0 else { return 0 }
        let edge = offset / pitch
        let target = step > 0 ? (edge + 0.001).rounded(.down) + 1 : (edge - 0.001).rounded(.up) - 1
        return min(max(target * pitch, 0), maxOffset)
    }
}
