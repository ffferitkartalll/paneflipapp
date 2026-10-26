import CoreGraphics
import Foundation

/// One swipe through a zone's windows, followed finger by finger: how far the fingers have taken the content (to the right is
/// positive: it shows the previous window) and how fast they were going when they lifted. Value type; pure.
public struct ScrubGesture: Equatable {
    /// How far the content has been taken, in points.
    public private(set) var offset: CGFloat = 0
    private var samples: [(time: TimeInterval, offset: CGFloat)] = []
    private var limits: ClosedRange<CGFloat> = -.infinity ... .infinity
    /// Where the fingers took hold again (see `resume`): what counts as a swipe is what they did since.
    private var resumedAt: CGFloat = 0

    /// A fast flick counts from this speed (points per second) and this distance, whatever the zone's width.
    public static let flickSpeed: CGFloat = 450
    public static let flickDistance: CGFloat = 24
    /// A slow swipe counts from this share of the zone's width.
    public static let dragShare: CGFloat = 0.3
    /// The speed is read over this long.
    private static let window: TimeInterval = 0.09

    public init() {}

    public static func == (a: ScrubGesture, b: ScrubGesture) -> Bool { a.offset == b.offset }

    /// Where the offset may go for the window `current` of `count` in a zone `zoneWidth` wide: not past the first window (to the
    /// right) nor the last (to the left), so nothing of the pictures' ends ever shows.
    public static func range(zoneWidth: CGFloat, current: Int, count: Int) -> ClosedRange<CGFloat> {
        -CGFloat(max(count - 1 - current, 0)) * zoneWidth ... CGFloat(max(current, 0)) * zoneWidth
    }

    /// Keeps the offset inside `range` from now on; the fingers going on past an end change nothing.
    public mutating func limit(to range: ClosedRange<CGFloat>) {
        limits = range
        offset = min(max(offset, range.lowerBound), range.upperBound)
    }

    /// The fingers came down again while the content still glided: the swipe goes on from where the content is (`offset`), and the speed
    /// of the earlier swipe is forgotten.
    public mutating func resume(at offset: CGFloat) {
        self.offset = min(max(offset, limits.lowerBound), limits.upperBound)
        resumedAt = self.offset
        samples = []
    }

    public mutating func add(_ delta: CGFloat, at time: TimeInterval) {
        offset = min(max(offset + delta, limits.lowerBound), limits.upperBound)
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

    /// The swipe is a flick: fast enough, far enough, and the fingers still going the way they went.
    public var isFlick: Bool { abs(speed) >= Self.flickSpeed && abs(offset - resumedAt) >= Self.flickDistance && speed * (offset - resumedAt) > 0 }

    /// Where the content would come to rest if it were let go now: where it is, and a fast flick adds the distance it would still go.
    public var landing: CGFloat {
        isFlick ? offset + speed * CGFloat(Self.coast) : offset
    }

    /// How many windows the swipe moves on when the fingers lift: positive toward the next windows (the content went to the left),
    /// negative toward the previous ones. A slow swipe moves on one window for each width of the zone it has gone, from 30 % of the
    /// first one; a fast flick adds the distance it would still go, and moves at least one window. The ends are not passed.
    public func shift(zoneWidth: CGFloat, current: Int, count: Int) -> Int {
        let projected = isFlick ? offset + speed * CGFloat(Self.coast) : offset
        var steps = Int((abs(projected) / zoneWidth + (1 - Self.dragShare)).rounded(.down))
        if isFlick { steps = max(steps, 1) }
        let wanted = projected > 0 ? -steps : steps
        return min(max(current + wanted, 0), count - 1) - current
    }
}
