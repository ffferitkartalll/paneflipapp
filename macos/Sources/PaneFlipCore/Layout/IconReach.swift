import CoreGraphics

/// Where a point counts as being on the menu bar icon: on it, or, while a window is dragged, within `reach` points of it (round it and below it), so that
/// the pointer need not hit it exactly.
public enum IconReach {
    public static func contains(_ point: CGPoint, iconMidX: CGFloat, iconWidth: CGFloat, displayTop: CGFloat, barHeight: CGFloat, reach: CGFloat) -> Bool {
        abs(point.x - iconMidX) <= iconWidth / 2 + reach && point.y >= displayTop - barHeight - reach
    }
}
