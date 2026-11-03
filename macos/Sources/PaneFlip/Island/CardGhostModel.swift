import Observation
import CoreGraphics

@Observable
final class CardGhostModel {
    var card: IslandWindow?
    /// The side of the glyph, in points.
    var icon: CGFloat = 32
}
