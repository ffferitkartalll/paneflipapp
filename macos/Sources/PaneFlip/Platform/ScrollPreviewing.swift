import CoreGraphics
import Foundation
import PaneFlipCore

/// A small map of the strip that shows where the screen is while its layout scrolls.
protocol ScrollPreviewing {
    /// The layout of `screen` stands `offset` screen widths to the right of its own place: the map is shown with its frame there (or its
    /// frame moves). Called on every frame of a scroll.
    func show(strip: StripLayout, offset: Double, on screen: ScreenInfo)

    /// The map goes away after `delay` seconds, unless it is shown again by then.
    func hide(after delay: TimeInterval)
}
