import Foundation

/// The proportions a split line sticks to in the layout editor: a quarter, a third, a half, two thirds and three quarters. Pure.
public enum SplitSnap {
    public static let shares: [(numerator: Int, denominator: Int)] = [(1, 4), (1, 3), (1, 2), (2, 3), (3, 4)]
    public static let steps: [Double] = shares.map { Double($0.numerator) / Double($0.denominator) }

    /// The step nearest to `ratio`, if it lies within `distance` points of it on a line `extent` points long.
    public static func step(near ratio: Double, extent: Double, distance: Double) -> Double? {
        guard let nearest = steps.min(by: { abs($0 - ratio) < abs($1 - ratio) }), abs(nearest - ratio) * extent < distance else { return nil }
        return nearest
    }

    /// The step as a share of the whole ("1/3" is (1, 3)); nil for a ratio that is not a step.
    public static func share(of ratio: Double) -> (numerator: Int, denominator: Int)? {
        steps.firstIndex { abs($0 - ratio) < 0.0001 }.map { shares[$0] }
    }

    public static func isStep(_ ratio: Double) -> Bool { steps.contains { abs($0 - ratio) < 0.0001 } }
}
