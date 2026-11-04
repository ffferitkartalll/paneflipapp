import CoreGraphics
import Foundation

/// Where the zones of a strip stand on a screen, and the scrolling arithmetic. `offset` is how far the screen has moved
/// to the right along the strip: 0 shows the screen's own layout, `trailing` brings the right overflow into view.
public struct StripGeometry: Equatable {

    /// A zone with less than this much of its width on the screen is out of sight: macOS does not let a window rest with a
    /// few pixels showing (it pulls it back to show about forty), so such a zone waits at the edge like the ones further out.
    public static let visibleEnough: CGFloat = 8

    public let strip: StripLayout
    public let screen: CGRect
    /// The gap between zones, and the margin of every screen of the strip (the screen's own and each area) round its edges.
    public let gap: CGFloat
    public let margin: CGFloat

    public init(strip: StripLayout, screen: CGRect, gap: CGFloat = 0, margin: CGFloat = 0) {
        self.strip = strip
        self.screen = screen
        self.gap = gap
        self.margin = margin
    }

    /// What is seen between the zones of two neighbouring screens is the larger of the gap and one margin (each screen has its margin, and the two meet there: they are not added,
    /// so a margin as wide as the gap leaves the gap). The screens stand that far apart less their two margins, which is below nothing where the margin is the larger part: their
    /// margins then overlap. Scrolling comes to rest with a screen in view, so it skips this space.
    public func screenGap(gap: CGFloat? = nil, margin: CGFloat? = nil) -> CGFloat {
        let m = margin ?? self.margin
        return max(gap ?? self.gap, m) - 2 * m
    }

    public var leadingWidth: CGFloat { screen.width * strip.leadingWidth + screenGap() * CGFloat(strip.leading.count) }
    public var trailingWidth: CGFloat { screen.width * strip.trailingWidth + screenGap() * CGFloat(strip.trailing.count) }

    /// The offsets the screen may have.
    public var range: ClosedRange<CGFloat> { -leadingWidth ... trailingWidth }

    /// The offsets where scrolling comes to rest: the screen's own layout and each area's far edge, on both sides. Scrolling goes from one screen to the next, never to a line between zones.
    /// The screen a view at `offset` shows when it is at a rest (within half a point of one); nil while it is between two.
    public func screen(restingAt offset: CGFloat) -> RestingScreen? {
        if abs(offset) < 0.5 { return .own }
        let apart = screenGap()
        var reached: CGFloat = 0
        for (i, area) in strip.trailing.enumerated() {
            reached += screen.width * area.width
            if abs(offset - (reached + apart * CGFloat(i + 1))) < 0.5 { return .trailing(i) }
        }
        reached = 0
        for (i, area) in strip.leading.enumerated() {
            reached += screen.width * area.width
            if abs(offset + (reached + apart * CGFloat(i + 1))) < 0.5 { return .leading(i) }
        }
        return nil
    }

    /// Where a view rests to show `resting`; nil for an area the strip does not have.
    public func restOffset(of resting: RestingScreen) -> CGFloat? {
        let apart = screenGap()
        switch resting {
        case .own: return 0
        case .trailing(let i):
            guard strip.trailing.indices.contains(i) else { return nil }
            return screen.width * strip.trailing[...i].reduce(0) { $0 + $1.width } + apart * CGFloat(i + 1)
        case .leading(let i):
            guard strip.leading.indices.contains(i) else { return nil }
            return -(screen.width * strip.leading[...i].reduce(0) { $0 + $1.width } + apart * CGFloat(i + 1))
        }
    }

    /// Where a view that rested at a screen of the strip when the gap and the margin were `gap` and `margin` rests now, for the same screen; nil if it did not rest at one.
    public func offset(keepingScreenOf offset: CGFloat, whenGapWas gap: CGFloat, marginWas margin: CGFloat) -> CGFloat? {
        let before = StripGeometry(strip: strip, screen: screen, gap: gap, margin: margin)
        return before.screen(restingAt: offset).flatMap(restOffset(of:))
    }

    /// A view rests where the far edge of an area stands at the far edge of the screen: the widths of the areas up to it, and the gap before each of them.
    public var rests: [CGFloat] {
        var offsets: [CGFloat] = [0]
        var reached: CGFloat = 0
        let apart = screenGap()
        for (i, area) in strip.trailing.enumerated() { reached += screen.width * area.width; offsets.append(reached + apart * CGFloat(i + 1)) }
        reached = 0
        for (i, area) in strip.leading.enumerated() { reached += screen.width * area.width; offsets.append(-(reached + apart * CGFloat(i + 1))) }
        return offsets.sorted()
    }

    public func clamped(_ offset: CGFloat) -> CGFloat { min(max(offset, range.lowerBound), range.upperBound) }

    /// The rectangle the screen's own layout is laid in when the strip rests at the screen (`offset` 0): the screen less its margin on every side, as each screen of the strip has it.
    public func rootArea(margin: CGFloat? = nil) -> CGRect {
        let m = margin ?? self.margin
        return CGRect(x: screen.minX + m, y: screen.minY + m, width: max(screen.width - 2 * m, 0), height: max(screen.height - 2 * m, 0))
    }

    /// Every zone of the strip as it stands when the screen has moved by `offset`. The screens of the strip (the screen's own and each area) stand `screenGap` apart, and each has
    /// its margin on all four sides; the gap lies between zones. Scrolling comes to rest with a screen in view, so the space between screens is not seen at rest.
    public func zones(offset: CGFloat, gap: CGFloat? = nil, margin: CGFloat? = nil) -> [Placed] {
        let gap = gap ?? self.gap, margin = margin ?? self.margin, apart = screenGap(gap: gap, margin: margin)
        let top = screen.minY + margin, height = max(screen.height - 2 * margin, 0)
        var placed: [(UUID, CGRect)] = []
        // The areas beyond the left edge, the nearest first, then laid in order across the strip.
        var end = screen.minX - apart
        var leftAreas: [[(UUID, CGRect)]] = []
        for area in strip.leading {
            let start = end - screen.width * area.width
            let rect = CGRect(x: start + margin, y: top, width: max(end - start - 2 * margin, 0), height: height)
            leftAreas.append(area.root.zones(in: rect, gap: gap).map { ($0.id, $0.rect) })
            end = start - apart
        }
        placed += leftAreas.reversed().flatMap { $0 }
        placed += strip.root.zones(in: rootArea(margin: margin), gap: gap).map { ($0.id, $0.rect) }
        var start = screen.maxX + apart
        for area in strip.trailing {
            let far = start + screen.width * area.width
            let rect = CGRect(x: start + margin, y: top, width: max(far - start - 2 * margin, 0), height: height)
            placed += area.root.zones(in: rect, gap: gap).map { ($0.id, $0.rect) }
            start = far + apart
        }
        return placed.map { id, rect in
            let moved = rect.offsetBy(dx: -offset, dy: 0)
            return Placed(id: id, rect: moved, isOnScreen: moved.intersection(screen).width >= Self.visibleEnough)
        }
    }
}
