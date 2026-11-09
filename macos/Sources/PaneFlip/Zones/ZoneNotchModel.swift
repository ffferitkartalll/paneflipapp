import CoreGraphics
import Observation

/// What a zone's notch shows (`ZoneNotchView`): at rest, lit under the pointer, or grown into a row of the zone's open windows while they are switched.
@Observable
final class ZoneNotchModel {
    var hovered = false
    /// The open windows of a switch, in the grown notch; empty: the notch is not grown.
    var cards: [IslandWindow] = []
    /// How wide each card of the grown notch is, in the order of `cards`, and how tall the notch is then.
    var widths: [CGFloat] = []
    var height: CGFloat = 0
    /// Which card is lit: its place among them, between two while the fingers lead.
    var lit: CGFloat = 0
    /// The card the pointer is on (its place among them), if any: one that is not lit gets a hover effect.
    var hoveredCard: Int?
    /// The card the mouse carries (`IslandWindow.id`) and where its middle is, from the left edge of the notch: it floats there, its place in the row empty.
    var carriedCard: String?
    var carriedX: CGFloat = 0
}
