import CoreGraphics
import Foundation

/// Which zone lies next to another one in a direction.
public enum ZoneNeighbour {
    /// The zone `zone` leads to when going `direction`: among those that start beyond its edge, the nearest of those that face it, and of
    /// two equally near the one whose number (the number a zone shows) follows the number of this zone most closely, the later one if
    /// two do alike (from 3 the zone 4 before the zone 5, from 3 the zone 2 before the zone 1); with none facing it, the nearest. Nil when there is
    /// none that way. `zones` may contain `zone` itself.
    public static func nearest<ID: Equatable>(to zone: CGRect, number: Int, among zones: [(id: ID, rect: CGRect, number: Int)], toward direction: ZoneDirection,
                                              tolerance: CGFloat = 2) -> ID? {
        let candidates = zones.filter { gap(from: zone, to: $0.rect, direction) >= -tolerance && $0.rect != zone }
        return candidates.min { score(zone, number, ($0.rect, $0.number), direction) < score(zone, number, ($1.rect, $1.number), direction) }?.id
    }

    /// How far the other zone starts beyond the edge of this one in the direction (negative: it starts inside).
    private static func gap(from a: CGRect, to b: CGRect, _ direction: ZoneDirection) -> CGFloat {
        switch direction {
        case .right: b.minX - a.maxX
        case .left: a.minX - b.maxX
        case .down: b.minY - a.maxY
        case .up: a.minY - b.maxY
        }
    }

    /// Smaller is better: zones that face this one first, then the nearer, then the number that follows this zone's most closely (the later one on a tie), then the middle that lies closer.
    private static func score(_ a: CGRect, _ own: Int, _ b: (rect: CGRect, number: Int), _ direction: ZoneDirection) -> (CGFloat, CGFloat, CGFloat, CGFloat, CGFloat) {
        let horizontal = direction == .left || direction == .right
        let rect = b.rect
        let shared = horizontal ? min(a.maxY, rect.maxY) - max(a.minY, rect.minY) : min(a.maxX, rect.maxX) - max(a.minX, rect.minX)
        let off = horizontal ? abs(a.midY - rect.midY) : abs(a.midX - rect.midX)
        let apart = shared > 0 ? CGFloat(abs(b.number - own)) : 0
        return (shared > 0 ? 0 : 1, max(gap(from: a, to: rect, direction), 0).rounded(), apart, shared > 0 ? -CGFloat(b.number) : 0, off)
    }
}
