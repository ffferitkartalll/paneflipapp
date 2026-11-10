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

    /// Where the lit frame stands among every slot of the zone, given where it stands among its open windows (between two while the fingers lead it): the apps that
    /// are not open lie between the windows, so the frame goes over them.
    private static func place(of position: CGFloat, among slots: [IslandWindow]) -> CGFloat {
        let open = slots.indices.filter { slots[$0].windowID != nil }
        guard !open.isEmpty else { return 0 }
        let at = min(max(position, 0), CGFloat(open.count - 1)), index = Int(at)
        let from = CGFloat(open[index]), to = CGFloat(open[min(index + 1, open.count - 1)])
        return from + (at - CGFloat(index)) * (to - from)
    }

    /// `values`, which are of the open windows `open`, for each of `cards` (every slot of the zone): 0 for an app that is not open.
    private static func place(_ values: [CGFloat], of cards: [IslandWindow], among open: [IslandWindow]) -> [CGFloat] {
        cards.map { card in open.firstIndex { $0.id == card.id }.map { values[$0] } ?? 0 }
    }

    var body: some View {
        let grown = !model.cards.isEmpty, g = model.grow, e = model.expand
        let rest = CGSize(width: NotchSize.size(forWindows: model.windowCount).width, height: NotchSize.size(forWindows: model.windowCount).height)
        let large = NotchSize.hoverSize(forWindows: model.windowCount)
        let lifted = CGSize(width: rest.width + (large.width - rest.width) * model.lift, height: rest.height + (large.height - rest.height) * model.lift)
        // One part for each open window, equal at rest; as they grow they become the cards, and, expanded, the cards of the island's row, with the apps that are not open
        // among them (no wider than a line at first).
        let slotted = !model.slots.isEmpty
        let cards = slotted ? model.slots : model.cards
        let count = grown ? model.widths.count : max(model.windowCount, 1)
        let part = lifted.width / CGFloat(max(count, 1))
        let openCells = grown ? model.widths.map { part + ($0 - part) * g } : Array(repeating: part, count: count)
        // The same for every card of the zone: what it is as an open window, 0 when it is not open.
        let widths = slotted ? Self.place(model.widths, of: cards, among: model.cards) : model.widths
        let compactCells = slotted ? Self.place(openCells, of: cards, among: model.cards) : openCells
        let cells = slotted ? compactCells.map { $0 + (model.cardWidth - $0) * e } : compactCells
        let more = grown ? model.height * g : 0
        let compactHeight = lifted.height + (grown ? (model.height - lifted.height) * g : 0)
        let expandedHeight = slotted ? ZoneNotchExpanded.size(count: model.slots.count, cardWidth: model.cardWidth).height : compactHeight
        let size = CGSize(width: cells.reduce(0, +) + more * (1 - e), height: compactHeight + (expandedHeight - compactHeight) * e)
        let radius = lifted.height / 2 + (Self.grownRadius - lifted.height / 2) * g
        let shape = UnevenRoundedRectangle(bottomLeadingRadius: radius, bottomTrailingRadius: radius, style: .circular)
        ZStack(alignment: .topLeading) {
            shape.fill(Color(nsColor: .windowBackgroundColor))
            ZoneNotchRow(cards: cards, widths: widths, cells: cells, height: compactHeight,
                         lit: slotted ? Self.place(of: model.lit, among: model.slots) : (grown ? model.lit : CGFloat(model.activeIndex)),
                         lift: model.lift, grow: g, expand: e, cardWidth: model.cardWidth, hovered: slotted ? model.hoveredSlot : (grown ? model.hoveredCard : nil),
                         hoveredButton: model.hoveredButton, carried: model.carriedCard, carriedX: model.carriedX, moreHovered: model.moreHovered)
        }
        .frame(width: size.width, height: size.height)
        .clipShape(shape)
        .overlay { shape.strokeBorder(AppAccent.color, lineWidth: 1) }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)   // at the top middle of its panel, which is as large as the notch can be now
    }
}
