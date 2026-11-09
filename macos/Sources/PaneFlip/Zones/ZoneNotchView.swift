import PaneFlipCore
import SwiftUI

/// A notch hangs from the top inner edge of a zone, in the middle: a small tab with the accent colour as its edge and the system's own colour inside. With the pointer on it,
/// it is twice as tall, no wider, and cut into as many parts as the zone has open windows, the front window's part filled with the accent colour; a press on it opens that row
/// without switching, a press on a card of the row brings its window forward. While the zone's windows are switched, or after a press, it grows into a row of its open windows
/// (`ZoneNotchRow`), each part turning into the card of its window, the one in front lit, the lit card sliding as the switch goes.
struct ZoneNotchView: View {
    /// The lower corners of the grown notch.
    static let grownRadius: CGFloat = 12
    let model: ZoneNotchModel

    var body: some View {
        let grown = !model.cards.isEmpty, g = model.grow
        let small = NotchSize.size(forWindows: model.windowCount), large = NotchSize.hoverSize(forWindows: model.windowCount)
        let rest = CGSize(width: small.width + (large.width - small.width) * model.lift, height: small.height + (large.height - small.height) * model.lift)
        // One part for each open window, equal at rest; as they grow they become the cards.
        let count = grown ? model.widths.count : max(model.windowCount, 1)
        let part = rest.width / CGFloat(max(count, 1))
        let cells = grown ? model.widths.map { part + ($0 - part) * g } : Array(repeating: part, count: count)
        let size = CGSize(width: cells.reduce(0, +), height: rest.height + (grown ? (model.height - rest.height) * g : 0))
        let radius = rest.height / 2 + (Self.grownRadius - rest.height / 2) * g
        let shape = UnevenRoundedRectangle(bottomLeadingRadius: radius, bottomTrailingRadius: radius, style: .circular)
        ZStack(alignment: .topLeading) {
            shape.fill(Color(nsColor: .windowBackgroundColor))
            ZoneNotchRow(cards: model.cards, widths: model.widths, cells: cells, height: size.height, lit: grown ? model.lit : CGFloat(model.activeIndex),
                         lift: model.lift, grow: g, hovered: model.hoveredCard, carried: model.carriedCard, carriedX: model.carriedX)
        }
        .frame(width: size.width, height: size.height)
        .clipShape(shape)
        .overlay { shape.strokeBorder(AppAccent.color, lineWidth: 1) }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)   // at the top middle of its panel, which is as large as the notch can be now
    }
}
