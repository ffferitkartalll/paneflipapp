import CoreGraphics
import Foundation

/// Turns the stream of scroll events over the pill into steps through its windows: a swipe or a turn of the wheel is one step,
/// not as many as it has events. After a step the pill does not listen for a moment, while the slide to the next window runs.
struct PillScrollStepper {
    /// How far a gesture must go before it counts: precise (trackpad) deltas are in points, a wheel's in lines.
    private static let preciseDistance: CGFloat = 10
    private static let wheelDistance: CGFloat = 1
    private static let pause: TimeInterval = 0.4

    private var travelled: CGFloat = 0
    private var deaf: TimeInterval = -.infinity

    /// -1 for a step back, 1 for a step on, 0 while the gesture has not gone far enough. A negative `delta` is a scroll toward later
    /// content (fingers up or left, the wheel turned down).
    mutating func step(delta: CGFloat, precise: Bool, at time: TimeInterval) -> Int {
        guard time >= deaf else { return 0 }
        travelled += delta
        guard abs(travelled) >= (precise ? Self.preciseDistance : Self.wheelDistance) else { return 0 }
        let direction = travelled < 0 ? 1 : -1
        travelled = 0
        deaf = time + Self.pause
        return direction
    }

    /// A new gesture starts from nothing.
    mutating func reset() { travelled = 0 }
}
