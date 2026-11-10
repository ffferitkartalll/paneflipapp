import AppKit
import SwiftUI

/// What a card of the notch expanded (`ZoneNotchExpanded`) has besides its picture and its title, which are the compact row's and move into place (`ZoneNotchRow`): the Dock's
/// badge at the top right, and the buttons of the card under the pointer, as the island's row has them. It is `width` wide while the
/// notch grows into it, its contents as large as they will be, in the middle.
struct ZoneNotchCard: View {
    let slot: IslandWindow
    /// How wide the card is now, and how wide it will be.
    let width: CGFloat
    let cardWidth: CGFloat
    let hovered: Bool
    let hoveredButton: IslandButton?

    var body: some View {
        let card = ZoneNotchExpanded.pictureSize(width: cardWidth)
        ZStack(alignment: .topLeading) {
            badge(in: card).opacity(hovered ? 0 : 1)
            if hovered { buttons(in: card) }
        }
        .frame(width: card.width, height: card.height)
        .frame(width: width)   // the card keeps its size and is cut by the notch while the notch is narrower
    }

    private static func fill(hover: Bool) -> Color { .black.opacity(hover ? 0.85 : 0.6) }

    private func buttons(in card: CGSize) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(IslandCardAction.rects(in: card, among: slot.actions), id: \.action) { item in
                Image(systemName: item.action.symbol).resizable().scaledToFit().fontWeight(.bold).foregroundStyle(.white)
                    .frame(width: item.rect.width * 0.5, height: item.rect.height * 0.5)
                    .frame(width: item.rect.width, height: item.rect.height)
                    .background(Circle().fill(Self.fill(hover: hoveredButton == .card(item.action, slot.id))))
                    .offset(x: item.rect.minX, y: item.rect.minY)
            }
            let rect = IslandCardAction.selectRect(in: card)
            ZStack {
                Circle().fill(Self.fill(hover: hoveredButton == .select(slot.id)))
                if slot.selected {
                    Image(systemName: "checkmark").resizable().scaledToFit().fontWeight(.bold).foregroundStyle(.white)
                        .frame(width: rect.width * 0.5, height: rect.height * 0.5)
                }
            }
            .frame(width: rect.width, height: rect.height)
            .offset(x: rect.minX, y: rect.minY)
        }
        // As large as the card, from its top left corner: an offset moves a button but not the room it takes.
        .frame(width: card.width, height: card.height, alignment: .topLeading)
    }

    private func badge(in card: CGSize) -> some View {
        let rect = IslandCardAction.rects(in: card, among: [.remove]).first?.rect ?? .zero
        return ZStack(alignment: .topLeading) {
            if let text = slot.badgeText {
                Text(verbatim: text)
                    .font(.system(size: rect.width * 0.5, weight: .bold)).foregroundStyle(.white)
                    .minimumScaleFactor(0.5).lineLimit(1).padding(.horizontal, 1)
                    .frame(width: rect.width, height: rect.height)
                    .background(Circle().fill(Color.red))
                    .offset(x: rect.minX, y: rect.minY)
            }
        }
        .frame(width: card.width, height: card.height, alignment: .topLeading)
    }
}
