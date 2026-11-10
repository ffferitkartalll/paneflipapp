import CoreGraphics
import PaneFlipCore

/// The numbers of the notch expanded into the island's row of cards (the one the "more" button opens): a card for each slot of the zone, side by side and against the notch's
/// edges, each a 16:9 card with its picture and its title in the middle, one above the other.
enum ZoneNotchExpanded {
    /// The title's height; the picture and the title are centred in the card together, `groupGap` apart.
    static let titleHeight: CGFloat = 16
    static let groupGap: CGFloat = 6
    static let narrowest: CGFloat = 48

    /// How wide a card is: as wide as the island's, narrower when the zone has no room for them all.
    static func cardWidth(island: CGFloat, count: Int, zoneWidth: CGFloat) -> CGFloat {
        max(narrowest, min(island, (zoneWidth - 2 * ZoneCorner.radius) / CGFloat(max(count, 1))))
    }

    /// A card: 16:9.
    static func pictureSize(width: CGFloat) -> CGSize { CGSize(width: width, height: (width * 9 / 16).rounded()) }

    static func cardHeight(width: CGFloat) -> CGFloat { pictureSize(width: width).height }

    static func size(count: Int, cardWidth: CGFloat) -> CGSize { CGSize(width: CGFloat(count) * cardWidth, height: cardHeight(width: cardWidth)) }

    /// The card at `x` from the left edge of the expanded notch (nil: outside it).
    static func index(atX x: CGFloat, count: Int, cardWidth: CGFloat) -> Int? {
        CardRow.index(atX: x, widths: Array(repeating: cardWidth, count: count))
    }
}
