import CoreGraphics

/// A card of the grid of a whole layout with its zone and its place in the layout, in the room of the display (before the grid is scrolled).
struct LayoutGridPlace {
    let zone: LayoutGridZone
    let card: IslandWindow
    let rect: CGRect
}
