import CoreGraphics

/// Where a row that is being carried would be dropped, for a stack of rows of known heights.
enum ReorderPlace {
    /// How far the row may travel without leaving the stack.
    static func limited(_ travel: CGFloat, heights: [CGFloat], from: Int) -> CGFloat {
        let top = heights[..<from].reduce(0, +)
        return min(max(travel, -top), heights.reduce(0, +) - top - heights[from])
    }

    /// The place the row takes when it has travelled `travel` points: moving down it passes a row once its bottom
    /// edge is below that row's middle, moving up once its top edge is above it. Judged by the leading edge, the
    /// first row can reach the end and the last one the start, where the middle of the row itself would stop short.
    static func target(heights: [CGFloat], from: Int, travel: CGFloat) -> Int {
        let tops = heights.indices.map { heights[..<$0].reduce(0, +) }
        let moved = limited(travel, heights: heights, from: from)
        let upper = tops[from] + moved
        let lower = upper + heights[from]
        func middle(_ i: Int) -> CGFloat { tops[i] + heights[i] / 2 }
        if moved >= 0 { return from + heights.indices.filter { $0 > from && middle($0) < lower }.count }
        return from - heights.indices.filter { $0 < from && middle($0) > upper }.count
    }
}
