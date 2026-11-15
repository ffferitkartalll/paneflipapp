import Foundation

/// Whoever carries the cards of a grid of a zone's windows beyond their zone: the grid of the whole layout, where a card can be put in any zone, on any display. A grid with
/// no carrier only changes the order of its own cards.
protocol ZoneCardCarrying: AnyObject {
    /// The mouse has taken `card` of `zone` and moved a little: it is carried from now on.
    func carryBegan(_ card: IslandWindow, from zone: ZoneWindowsModel)
    /// The mouse moved with the card (the pointer is read from the screen: the carried card is not in the room of its zone any more).
    func carryMoved()
    /// The mouse was let go.
    func carryEnded(_ card: IslandWindow, from zone: ZoneWindowsModel)
}
