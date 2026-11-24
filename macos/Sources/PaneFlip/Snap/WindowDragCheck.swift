import CoreGraphics

/// Tells a window drag from the other things a mouse can do on a window.
enum WindowDragCheck {
    /// The window itself moved: its corner went more than 4 points and its size stayed (within 2 points). Not a resize, not a click or a text selection inside it.
    static func isMove(from start: CGRect, to now: CGRect) -> Bool {
        hypot(now.minX - start.minX, now.minY - start.minY) > 4
            && abs(now.width - start.width) < 2 && abs(now.height - start.height) < 2
    }
}
