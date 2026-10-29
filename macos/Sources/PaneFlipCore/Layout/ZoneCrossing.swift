import CoreGraphics

/// Going from a zone to the display that lies beside it: which zone of that display is entered, so that the light stays at the same place along the edge.
public enum ZoneCrossing {
    /// How far along the edge being crossed a zone lies, from 0 to 1: the vertical place of the zone when the move is to the left or the right, the horizontal
    /// place when it is up or down. A zone out of sight has none; the middle.
    public static func along(_ zone: CGRect, onScreen: Bool, in screen: CGRect, going direction: ZoneDirection) -> CGFloat {
        guard onScreen, screen.width > 0, screen.height > 0 else { return 0.5 }
        let value = direction == .left || direction == .right ? (zone.midY - screen.minY) / screen.height : (zone.midX - screen.minX) / screen.width
        return min(max(value, 0), 1)
    }

    /// The zone nearest to the edge the move enters by, at the place `along` it: going right the left edge is entered, going up the bottom edge. `zones` are
    /// those on the screen of the display entered, in the same coordinates as `screen`.
    public static func entered<ID>(going direction: ZoneDirection, along: CGFloat, among zones: [(id: ID, rect: CGRect)], screen: CGRect) -> ID? {
        let point: CGPoint
        switch direction {
        case .right: point = CGPoint(x: screen.minX, y: screen.minY + along * screen.height)
        case .left: point = CGPoint(x: screen.maxX, y: screen.minY + along * screen.height)
        case .down: point = CGPoint(x: screen.minX + along * screen.width, y: screen.minY)
        case .up: point = CGPoint(x: screen.minX + along * screen.width, y: screen.maxY)
        }
        func distance(_ rect: CGRect) -> CGFloat {
            let dx = max(rect.minX - point.x, 0, point.x - rect.maxX), dy = max(rect.minY - point.y, 0, point.y - rect.maxY)
            return (dx * dx + dy * dy).squareRoot()
        }
        return zones.min { distance($0.rect) < distance($1.rect) }?.id
    }
}
