import CoreGraphics
import Foundation
import PaneFlipCore

/// What the grid of the whole layout is to show on one display: the zones of its layout where they stand now, with their cards, and where the layout rests when scrolled.
struct LayoutGridPlan {
    let screen: ScreenInfo
    /// The side of the display the windows wait at, nil when the layout has no screen beyond its edges.
    let side: Parking.Side?
    /// How far the layout was scrolled.
    let offset: CGFloat
    let rests: [CGFloat]
    /// The cards are read after the pictures were asked for (`LayoutGridOverlay.show`).
    var zones: [(id: UUID, rect: CGRect, cards: [IslandWindow])]
}
