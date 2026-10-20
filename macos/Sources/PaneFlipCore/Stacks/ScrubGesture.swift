import CoreGraphics
import Foundation

/// One swipe through a zone's windows, followed finger by finger: how far the fingers have taken the content (to the right is
/// positive: it shows the previous window) and how fast they were going when they lifted. Value type; pure.
public struct ScrubGesture: Equatable {
    /// How far the content has been taken, in points.
    public private(set) var offset: CGFloat = 0
    private var samples: [(time: TimeInterval, offset: CGFloat)] = []

    /// A fast flick counts from this speed (points per second) and this distance, whatever the zone's width.
    public static let flickSpeed: CGFloat = 450
    public static let flickDistance: CGFloat = 24
    /// A slow swipe counts from this share of the zone's width.
    public static let dragShare: CGFloat = 0.3
    /// The speed is read over this long.
    private static let window: TimeInterval = 0.09

    public init() {}

    public static func == (a: ScrubGesture, b: ScrubGesture) -> Bool { a.offset == b.offset }

    public mutating func add(_ delta: CGFloat, at time: TimeInterval) {
        offset += delta
        samples.append((time, offset))
        samples.removeAll { time - $0.time > Self.window * 3 }
    }

    /// The speed the fingers had at the end, in points per second.
    public var speed: CGFloat {
        guard let last = samples.last, let first = samples.first(where: { last.time - $0.time <= Self.window }), last.time > first.time else { return 0 }
        return (last.offset - first.offset) / CGFloat(last.time - first.time)
    }

    /// How far the fingers carry the content after they lift: a fast flick goes on a little further.
    public static let coast: TimeInterval = 0.15

    /// Where the content would come to rest if it were let go now: where it is, and a fast flick adds the distance it would still go.
    public var landing: CGFloat {
        abs(speed) >= Self.flickSpeed && abs(offset) >= Self.flickDistance && speed * offset > 0 ? offset + speed * CGFloat(Self.coast) : offset
    }

    /// How many windows the swipe moves on when the fingers lift: positive toward the next windows (the content went to the left),
    /// negative toward the previous ones. A slow swipe moves on one window for each width of the zone it has gone, from 30 % of the
    /// first one; a fast flick adds the distance it would still go, and moves at least one window. The ends are not passed.
    public func shift(zoneWidth: CGFloat, current: Int, count: Int) -> Int {
        let isFlick = abs(speed) >= Self.flickSpeed && abs(offset) >= Self.flickDistance && speed * offset > 0
        let projected = isFlick ? offset + speed * CGFloat(Self.coast) : offset
        var steps = Int((abs(projected) / zoneWidth + (1 - Self.dragShare)).rounded(.down))
        if isFlick { steps = max(steps, 1) }
        let wanted = projected > 0 ? -steps : steps
        return min(max(current + wanted, 0), count - 1) - current
    }
}
