import CoreGraphics
import PaneFlipCore

/// The height of the pill.
enum PillMetrics {
    static let height: CGFloat = 52

    /// The panel of a pill of the width `width` in a zone: the pill as a whole (segments and buttons) is centred on the zone, one
    /// menu-bar height from its top or from its bottom. The toolbar centres its items in the panel, so the panel is centred.
    static func panelFrame(inZone zone: CGRect, width: CGFloat, menuBarThickness: CGFloat, position: PillPosition = .top) -> CGRect {
        let y = position == .top ? zone.minY + menuBarThickness : zone.maxY - menuBarThickness - height
        return CGRect(x: zone.midX - width / 2, y: y, width: width, height: height)
    }
}
