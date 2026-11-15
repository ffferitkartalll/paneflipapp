import Foundation

/// A card carried to another zone in the grid of the whole layout: it stays in its zone until the grid is closed, and goes then.
struct LayoutGridMove: Equatable {
    let card: IslandWindow
    /// The zone the card was in when the grid opened, and the one it was carried to.
    let origin: UUID
    var target: UUID
    /// Where it stands among the cards of the zone it was carried to.
    var index: Int
}
