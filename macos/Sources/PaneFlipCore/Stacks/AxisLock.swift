import CoreGraphics

/// Decides at the start of a two-finger swipe whether it is a horizontal one, and keeps to that for the whole swipe: a swipe that
/// starts up or down never moves anything, and one that starts to the side ignores the fingers' drift up and down. Value type; pure.
public struct AxisLock: Equatable {
    public enum Decision: Equatable { case undecided, horizontal, vertical }

    public private(set) var decision = Decision.undecided
    private var sideways: CGFloat = 0
    private var upDown: CGFloat = 0

    /// How far the fingers must have gone, in points, before the direction is decided.
    public static let travel: CGFloat = 8
    /// How much more the fingers must have gone sideways than up or down for the swipe to count as horizontal.
    public static let bias: CGFloat = 1.25

    public init() {}

    /// The fingers moved. Returns how far the content follows now to the side: nothing while the direction is not decided or when it is
    /// vertical, and the whole distance of the start at the moment it turns out horizontal.
    public mutating func add(horizontal: CGFloat, vertical: CGFloat) -> CGFloat {
        switch decision {
        case .vertical: return 0
        case .horizontal: return horizontal
        case .undecided:
            sideways += horizontal
            upDown += vertical
            guard (sideways * sideways + upDown * upDown).squareRoot() >= Self.travel else { return 0 }
            decision = abs(sideways) > abs(upDown) * Self.bias ? .horizontal : .vertical
            return decision == .horizontal ? sideways : 0
        }
    }
}
