import Foundation

/// Follows a sideways swipe with three fingers from the trackpad's touch frames. A finger that lifts a moment before the
/// others does not end the swipe, and the swipe ends only once the fingers are up. Positions are fractions of the
/// trackpad's width.
public struct SwipeTracker {
    public enum Event: Equatable {
        case began
        /// How far the fingers have moved since the swipe began (right is positive).
        case moved(Double)
        /// The fingers lifted; `velocity` is in trackpad widths per second.
        case ended(velocity: Double)
    }

    private enum State {
        case idle
        /// Four or more fingers are down: not this swipe, whatever comes next, until they are up.
        case waitingForRelease
        case swiping
    }

    private let fingers: Int
    private let grace: TimeInterval
    private let window: TimeInterval
    private var state = State.idle
    private var anchor = 0.0
    private var distance = 0.0
    private var lostAt: TimeInterval?
    private var samples: [(time: TimeInterval, distance: Double)] = []

    public init(fingers: Int = 3, grace: TimeInterval = 0.15, velocityWindow: TimeInterval = 0.12) {
        self.fingers = fingers
        self.grace = grace
        self.window = velocityWindow
    }

    /// One frame of touches: how many fingers, where their centre is, and when.
    public mutating func frame(fingerCount: Int, x: Double, time: TimeInterval) -> [Event] {
        switch state {
        case .idle:
            // Fingers land one after the other (one, two, three): only more than three rule the swipe out.
            guard fingerCount == fingers else {
                if fingerCount > fingers { state = .waitingForRelease }
                return []
            }
            state = .swiping
            anchor = x
            distance = 0
            lostAt = nil
            samples = [(time, 0)]
            return [.began]
        case .waitingForRelease:
            if fingerCount == 0 { state = .idle }
            return []
        case .swiping:
            if fingerCount == fingers {
                if lostAt != nil { anchor = x - distance }   // the centre jumped when a finger came back
                lostAt = nil
                distance = x - anchor
                samples.append((time, distance))
                return [.moved(distance)]
            }
            let since = lostAt ?? time
            lostAt = since
            guard fingerCount == 0 || time - since > grace else { return [] }
            state = fingerCount > fingers ? .waitingForRelease : .idle
            return [.ended(velocity: velocity())]
        }
    }

    private func velocity() -> Double {
        guard let last = samples.last, let first = samples.first(where: { last.time - $0.time <= window }), last.time - first.time > 0.02
        else { return 0 }
        return (last.distance - first.distance) / (last.time - first.time)
    }
}
