import CoreGraphics
import Foundation

/// Tells a shake of the pointer from side to side: a few quick turns, each after a swing of some length. Pure: fed the pointer's place.
public struct ShakeDetector {
    /// How far the pointer must go back, from where it turned, for the turn to count, in points.
    public var swing: CGFloat = 60
    /// How many turns make a shake (two swings there and back are four turns), and the time they must come within, in seconds.
    public var turns = 4
    public var within: TimeInterval = 0.9

    private var direction = 0   // 1: to the right, -1: to the left, 0: not yet known
    private var extreme: CGFloat = 0
    private var turned: [TimeInterval] = []

    public init() {}

    /// The pointer is at `x` at `time`. True when this completes a shake; the detector then starts afresh.
    public mutating func feed(x: CGFloat, at time: TimeInterval) -> Bool {
        if direction == 0 {
            if turned.isEmpty, extreme == 0 { extreme = x }
            if abs(x - extreme) >= swing { direction = x > extreme ? 1 : -1; extreme = x }
            return false
        }
        if (direction == 1 && x > extreme) || (direction == -1 && x < extreme) {
            extreme = x
            return false
        }
        guard abs(x - extreme) >= swing else { return false }
        direction = -direction
        extreme = x
        turned.append(time)
        turned.removeAll { time - $0 > within }
        guard turned.count >= turns else { return false }
        reset()
        return true
    }

    public mutating func reset() {
        direction = 0
        extreme = 0
        turned = []
    }
}
