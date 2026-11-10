import CoreGraphics
import Observation

/// What a zone's notch shows (`ZoneNotchView`): at rest, lit under the pointer, or grown into a row of the zone's open windows while they are switched.
@Observable
final class ZoneNotchModel {
    /// 0 for the notch at rest, 1 for the one the pointer is on (and for the grown one): moved by the owner, so that it goes from one to the other as a movement.
    var lift: CGFloat = 0
    /// 0 for the notch at rest, 1 for the grown one: how far each part has turned into the card of its window (`ZoneNotchRow`).
    var grow: CGFloat = 0
    /// How many open windows the zone holds: the notch at rest is as wide as they ask (`ZoneNotchView.size(forWindows:)`).
    var windowCount = 1
    /// The place of the zone's front window among them: with the pointer on the notch, that part of it is filled.
    var activeIndex = 0
    /// The open windows of a switch, in the grown notch; empty: the notch is not grown.
    var cards: [IslandWindow] = []
    /// How wide each card of the grown notch is, in the order of `cards`, and how tall the notch is then.
    var widths: [CGFloat] = []
    var height: CGFloat = 0
    /// Which card is lit: its place among them, between two while the fingers lead.
    var lit: CGFloat = 0
    /// 0 for the compact row, 1 for the notch expanded into the island's row of cards (`ZoneNotchCards`): the "more" button.
    var expand: CGFloat = 0
    /// Every slot of the zone while it is expanded (its windows and the apps that are not open), how wide each card is, and the card and button the pointer is on.
    var slots: [IslandWindow] = []
    var cardWidth: CGFloat = 0
    var hoveredSlot: Int?
    var hoveredButton: IslandButton?
    /// The pointer is on the "more" button.
    var moreHovered = false
    /// The card the pointer is on (its place among them), if any: one that is not lit gets a hover effect.
    var hoveredCard: Int?
    /// The card the mouse carries (`IslandWindow.id`) and where its middle is, from the left edge of the notch: it floats there, its place in the row empty.
    var carriedCard: String?
    var carriedX: CGFloat = 0
}
