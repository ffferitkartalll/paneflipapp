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

    public var leadingWidth: CGFloat { screen.width * (strip.leading?.width ?? 0) }
    public var trailingWidth: CGFloat { screen.width * (strip.trailing?.width ?? 0) }

    /// The offsets the screen may have.
    public var range: ClosedRange<CGFloat> { -leadingWidth ... trailingWidth }

    /// The offsets where scrolling comes to rest: both ends and the screen's own layout.
    public var rests: [CGFloat] { Array(Set([-leadingWidth, 0, trailingWidth])).sorted() }

    public func clamped(_ offset: CGFloat) -> CGFloat { min(max(offset, range.lowerBound), range.upperBound) }

    /// Every zone of the strip as it stands when the screen has moved by `offset`.
    public func zones(offset: CGFloat, gap: CGFloat = 0) -> [Placed] {
        var placed: [(UUID, CGRect)] = []
        if let l = strip.leading {
            let rect = CGRect(x: screen.minX - leadingWidth, y: screen.minY, width: leadingWidth, height: screen.height)
            placed += l.root.zones(in: rect, gap: gap).map { ($0.id, $0.rect) }
        }
        placed += strip.root.zones(in: screen, gap: gap).map { ($0.id, $0.rect) }
        if let t = strip.trailing {
            let rect = CGRect(x: screen.maxX, y: screen.minY, width: trailingWidth, height: screen.height)
            placed += t.root.zones(in: rect, gap: gap).map { ($0.id, $0.rect) }
        }
        return placed.map { id, rect in
            let moved = rect.offsetBy(dx: -offset, dy: 0)
            return Placed(id: id, rect: moved, isOnScreen: moved.intersection(screen).width >= Self.visibleEnough)
        }
    }
}
