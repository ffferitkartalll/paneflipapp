import CoreGraphics
import Foundation

/// What a zone's notch asks the island for: the cards of a zone's windows as the island's row has them, and what the island does when one is clicked, its buttons are
/// pressed or it is put in another place. The notch shows and does what the island's row does, from the one source.
protocol ZoneCardSource: AnyObject {
    /// Asks the Dock for the apps' badges again (the cards change when it has answered).
    func refreshBadges()
    /// The open windows of a zone, in the order of the zone.
    func cards(of zone: UUID) -> [IslandWindow]
    /// Every card of the zone's row: its windows and the apps of the zone that are not open.
    func allCards(of zone: UUID) -> [IslandWindow]
    /// How wide the open island writes the title of a card on the display of `zone`.
    func titleWidth(of zone: UUID) -> CGFloat?
    /// A card is put in the place of another one: the windows of the zone stand in the new order.
    func move(_ card: IslandWindow, toPlaceOf other: IslandWindow, in zone: UUID)
    /// A click on a card: its window comes to the front of the zone and the focus goes with it (twice in a row on the front one: enlarged); an app that is not open is opened.
    func choose(_ card: IslandWindow, in zone: UUID)
    /// A button of a card.
    func perform(_ action: IslandCardAction, on card: IslandWindow, in zone: UUID)
    /// The button that ticks the card's app to be started with the layout.
    func toggleStart(_ card: IslandWindow, in zone: UUID)
}
