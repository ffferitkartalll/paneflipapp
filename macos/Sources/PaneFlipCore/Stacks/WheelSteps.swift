import CoreGraphics
import Foundation

/// Turns the smooth stream a mouse driver makes of a wheel (dozens of small scroll events for one click, with no touch phases) back into steps: one at the first
/// move of a stream, and another for each further `distance` points the wheel goes on the same way. Value type; pure.
public struct WheelSteps {
    /// A stream is over when no event has come for this long, in seconds.
    public static let idle: TimeInterval = 0.15
    /// shortcut: tuned to one slow click being about 400 points of a driver's stream; a faster flick is worth more, so it gives a few more steps. Change it if a click steps twice.
    public static let distance: CGFloat = 800

    private var last: TimeInterval?
    private var direction = 0
    private var travelled: CGFloat = 0

    public init() {}

    /// The wheel moved by `points` (negative: toward you) at `time`. Returns the steps to take: -1 for a step back, 1 for a step on, 0 for none.
    public mutating func add(_ points: CGFloat, at time: TimeInterval) -> Int {
        defer { last = time }
        if let last, time - last > Self.idle { direction = 0; travelled = 0 }
        guard points != 0 else { return 0 }
        let sign = points < 0 ? -1 : 1
        if sign != direction { direction = sign; travelled = 0; return sign }
        travelled += abs(points)
        guard travelled >= Self.distance else { return 0 }
        travelled -= Self.distance
        return sign
    }
}
