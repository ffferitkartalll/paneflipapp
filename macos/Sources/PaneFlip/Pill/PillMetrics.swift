import CoreGraphics

/// The height of the pill.
enum PillMetrics {
    static let height: CGFloat = 52

    /// The panel of a pill of the width `width` in a zone: the pill as a whole (segments and buttons) is centred on the zone, one
    /// menu-bar height below its top. The toolbar centres its items in the panel, so the panel is centred.
    static func panelFrame(inZone zone: CGRect, width: CGFloat, menuBarThickness: CGFloat) -> CGRect {
        CGRect(x: zone.midX - width / 2, y: zone.minY + menuBarThickness, width: width, height: height)
    }
}
