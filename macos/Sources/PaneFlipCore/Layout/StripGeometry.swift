import CoreGraphics
import Foundation

/// Where the zones of a strip stand on a screen, and the scrolling arithmetic. `offset` is how far the screen has moved
/// to the right along the strip: 0 shows the screen's own layout, `trailing` brings the right overflow into view.
public struct StripGeometry: Equatable {
    public struct Placed: Equatable {
        public let id: UUID
        public let rect: CGRect
        public let isOnScreen: Bool
    }

    /// A zone with less than this much of its width on the screen is out of sight: macOS does not let a window rest with a
    /// few pixels showing (it pulls it back to show about forty), so such a zone waits at the edge like the ones further out.
    public static let visibleEnough: CGFloat = 8

    private let strip: StripLayout
    private let screen: CGRect

    public init(strip: StripLayout, screen: CGRect) {
        self.strip = strip
        self.screen = screen
    }

    public var leadingWidth: CGFloat { screen.width * strip.leadingWidth }
    public var trailingWidth: CGFloat { screen.width * strip.trailingWidth }

    /// The offsets the screen may have.
    public var range: ClosedRange<CGFloat> { -leadingWidth ... trailingWidth }

    /// The offsets where scrolling comes to rest: the screen's own layout and each area's far edge, on both sides.
    public var rests: [CGFloat] {
        var offsets: Set<CGFloat> = [0]
        var reached: CGFloat = 0
        for area in strip.trailing { reached += screen.width * area.width; offsets.insert(reached) }
        reached = 0
        for area in strip.leading { reached += screen.width * area.width; offsets.insert(-reached) }
        return offsets.sorted()
    }

    public func clamped(_ offset: CGFloat) -> CGFloat { min(max(offset, range.lowerBound), range.upperBound) }

    /// Every zone of the strip as it stands when the screen has moved by `offset`. The strip is one band: the gap lies between
    /// its zones, also between the screen's layout and an area, and between one area and the next, and the margin runs round
    /// the whole band, so it lies at the far ends of the outermost areas, not between the screen and its areas.
    public func zones(offset: CGFloat, gap: CGFloat = 0, margin: CGFloat = 0) -> [Placed] {
        let half = gap / 2
        let top = screen.minY + margin, height = max(screen.height - 2 * margin, 0)
        var placed: [(UUID, CGRect)] = []
        // The areas beyond the left edge, the nearest first, then laid in order across the strip.
        var edge = screen.minX
        var leftAreas: [[(UUID, CGRect)]] = []
        for (i, area) in strip.leading.enumerated() {
            let width = screen.width * area.width
            let x = edge - width + (i == strip.leading.count - 1 ? margin : half)
            let rect = CGRect(x: x, y: top, width: max(edge - half - x, 0), height: height)
            leftAreas.append(area.root.zones(in: rect, gap: gap).map { ($0.id, $0.rect) })
            edge -= width
        }
        placed += leftAreas.reversed().flatMap { $0 }
        let from = strip.leading.isEmpty ? screen.minX + margin : screen.minX + half
        let to = strip.trailing.isEmpty ? screen.maxX - margin : screen.maxX - half
        placed += strip.root.zones(in: CGRect(x: from, y: top, width: max(to - from, 0), height: height), gap: gap).map { ($0.id, $0.rect) }
        edge = screen.maxX
        for (i, area) in strip.trailing.enumerated() {
            let width = screen.width * area.width
            let end = edge + width - (i == strip.trailing.count - 1 ? margin : half)
            let rect = CGRect(x: edge + half, y: top, width: max(end - edge - half, 0), height: height)
            placed += area.root.zones(in: rect, gap: gap).map { ($0.id, $0.rect) }
            edge += width
        }
        return placed.map { id, rect in
            let moved = rect.offsetBy(dx: -offset, dy: 0)
            return Placed(id: id, rect: moved, isOnScreen: moved.intersection(screen).width >= Self.visibleEnough)
        }
    }
}
