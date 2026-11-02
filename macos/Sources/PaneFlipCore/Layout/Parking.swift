import CoreGraphics

/// Where a window stands that belongs to a zone outside the screen: macOS lets a window rest with a single pixel on a
/// display and the rest beyond its left or right edge, so the window is out of sight unless another display lies there.
public enum Parking {
    public enum Side: Equatable { case left, right }

    /// A side of `display` with no other display beside it (in the same band of height): a parked window reaches over
    /// nothing there. Nil when both sides have one, and parking is not possible. All frames in the same coordinates.
    public static func side(of display: CGRect, others: [CGRect]) -> Side? {
        func beside(_ other: CGRect) -> Bool { other.minY < display.maxY && other.maxY > display.minY }
        if !others.contains(where: { beside($0) && $0.minX >= display.maxX - 1 }) { return .right }
        if !others.contains(where: { beside($0) && $0.maxX <= display.minX + 1 }) { return .left }
        return nil
    }

    /// `zone` moved so one pixel of it stays on `display`, at `side`; its size and height stay.
    public static func frame(for zone: CGRect, on display: CGRect, side: Side) -> CGRect {
        let x = side == .right ? display.maxX - 1 : display.minX - zone.width + 1
        return CGRect(x: x, y: zone.minY, width: zone.width, height: zone.height)
    }

    /// `zone` held where a window can really stand: at least one pixel of it stays on `display`, because macOS does not let
    /// a window rest entirely beyond a display's left or right edge.
    public static func standing(_ zone: CGRect, on display: CGRect) -> CGRect {
        var result = zone
        result.origin.x = min(max(zone.minX, display.minX - zone.width + 1), display.maxX - 1)
        return result
    }
}
