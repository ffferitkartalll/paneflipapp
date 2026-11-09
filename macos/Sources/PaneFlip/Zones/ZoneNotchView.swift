import SwiftUI

/// A notch hangs from the top inner edge of a zone, in the middle: a small tab with the accent colour as its edge and the system's own colour inside. With the pointer on it,
/// it is twice as large (it grows to the left, the right and down) and filled with the accent colour; a press on it opens that row without switching, a press on a card of the row brings its window forward. While
/// the zone's windows are switched it grows into a row of its open windows (`ZoneNotchRow`), the one in front lit, the lit card sliding as the switch goes.
struct ZoneNotchView: View {
    static let size = CGSize(width: 56, height: 6)
    static let hoverSize = CGSize(width: size.width * 2, height: size.height * 2)
    /// The lower corners of the grown notch.
    static let grownRadius: CGFloat = 12
    let model: ZoneNotchModel

    var body: some View {
        let grown = !model.cards.isEmpty
        let size = grown ? CGSize(width: model.widths.reduce(0, +), height: model.height) : model.hovered ? Self.hoverSize : Self.size
        let radius = grown ? Self.grownRadius : size.height / 2
        let shape = UnevenRoundedRectangle(bottomLeadingRadius: radius, bottomTrailingRadius: radius, style: .circular)
        ZStack(alignment: .topLeading) {
            shape.fill(model.hovered && !grown ? AppAccent.color : Color(nsColor: .windowBackgroundColor))
            if grown { ZoneNotchRow(cards: model.cards, widths: model.widths, height: model.height, lit: model.lit, hovered: model.hoveredCard, carried: model.carriedCard, carriedX: model.carriedX) }
        }
        .frame(width: size.width, height: size.height)
        .clipShape(shape)
        .overlay { shape.strokeBorder(AppAccent.color, lineWidth: 1) }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)   // at the top middle of its panel, which is as large as the notch can be now
        .animation(.easeOut(duration: 0.15), value: model.hovered)
    }
}
