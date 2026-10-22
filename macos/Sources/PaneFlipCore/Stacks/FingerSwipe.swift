import CoreGraphics
import Foundation

/// Turns what the trackpad says about the fingers on it (how many, and where their centre is) into a swipe with three or four fingers
/// that goes to the side: it begins when the fingers have settled and move to the side, and ends when they lift or their number changes.
/// Fingers land one after another, so a swipe with four does not begin as one with three. Value type; pure.
public struct FingerSwipe {
    public enum Output: Equatable {
        case began(fingers: Int)
        /// The fingers moved by this much (to the right is positive), at this time in seconds.
        case moved(CGFloat, at: TimeInterval)
        case ended
    }

    /// How far a swipe across the whole trackpad goes, in points of scrolling (what two fingers scroll for the same stroke).
    public static let travel: CGFloat = 800
    /// How many reports with the same number of fingers come before their movement counts.
    private static let settling = 4

    private var fingers = 0
    private var settled = 0
    private var last = CGPoint.zero
    private var axis = AxisLock()
    private var active = false
    /// A swipe ended because a finger came or went: nothing begins again until the fingers are down to two.
    private var locked = false

    public init() {}

    /// The trackpad reported `count` fingers with their centre at `x`, `y` (0 to 1 across the trackpad).
    public mutating func add(fingers count: Int, x: Double, y: Double, at time: TimeInterval) -> [Output] {
        guard (3...4).contains(count) else {
            let ended = finish()
            fingers = 0
            settled = 0
            axis = AxisLock()
            if count < 3 { locked = false } else { locked = true }   // five fingers are a pinch or a spread
            return ended
        }
        guard !locked else { return [] }
        let centre = CGPoint(x: x, y: y)
        guard count == fingers else {
            let ended = finish()
            locked = !ended.isEmpty
            fingers = count
            settled = 0
            axis = AxisLock()
            last = centre
            return ended
        }
        settled += 1
        guard settled >= Self.settling else {
            last = centre
            return []
        }
        let delta = axis.add(horizontal: (centre.x - last.x) * Self.travel, vertical: (centre.y - last.y) * Self.travel)
        last = centre
        guard delta != 0 else { return [] }
        var outputs: [Output] = []
        if !active {
            active = true
            outputs.append(.began(fingers: count))
        }
        outputs.append(.moved(delta, at: time))
        return outputs
    }

    private mutating func finish() -> [Output] {
        guard active else { return [] }
        active = false
        return [.ended]
    }
}
