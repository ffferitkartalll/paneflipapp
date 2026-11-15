import AppKit
import PaneFlipCore

/// One display of the grid of a whole layout: the display, its panel, what the panel shows, and how it has been scrolled by the wheel.
final class LayoutGridDisplay {
    let screen: ScreenInfo
    /// The whole display, and its usable area, in Accessibility coordinates (the panel covers the usable area).
    let frame: CGRect
    let area: CGRect
    /// How far the layout was scrolled when the grid opened.
    let offset: CGFloat
    let model: LayoutGridModel
    let panel: NSPanel

    init(screen: ScreenInfo, frame: CGRect, area: CGRect, offset: CGFloat, model: LayoutGridModel, panel: NSPanel) {
        self.screen = screen
        self.frame = frame
        self.area = area
        self.offset = offset
        self.model = model
        self.panel = panel
    }
}
