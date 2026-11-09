import CoreGraphics

/// How large the notch of a zone is at rest: the more open windows the zone holds, the wider it is.
public enum NotchSize {
    public static let height: CGFloat = 6
    public static let narrowest: CGFloat = 36
    public static let widest: CGFloat = 120
    /// 24 pt and 12 pt for each window (a zone without one is drawn as one with one), 120 pt at most.
    public static func size(forWindows count: Int) -> CGSize {
        CGSize(width: min(24 + 12 * CGFloat(max(count, 1)), widest), height: height)
    }

    /// With the pointer on it, twice as tall, no wider.
    public static func hoverSize(forWindows count: Int) -> CGSize {
        let size = size(forWindows: count)
        return CGSize(width: size.width, height: size.height * 2)
    }
}
