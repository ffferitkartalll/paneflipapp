import AppKit
import SwiftUI

/// What a card of the notch expanded (`ZoneNotchExpanded`) has besides its picture, its title and its badge, which are the compact row's and move into place (`ZoneNotchRow`): the
/// buttons of the card under the pointer, as the island's row has them. It is `width` wide while the
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
            buttons(in: card)
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
                    .animation(.easeOut(duration: 0.1), value: hoveredButton)
                    .offset(x: item.rect.minX, y: item.rect.minY)
            }
            let rect = IslandCardAction.selectRect(in: card)
            ZStack {
                Circle().fill(Self.fill(hover: hoveredButton == .select(slot.id)))
                    .animation(.easeOut(duration: 0.1), value: hoveredButton)
                Image(systemName: "checkmark").resizable().scaledToFit().fontWeight(.bold).foregroundStyle(.white)
                    .frame(width: rect.width * 0.5, height: rect.height * 0.5)
                    .scaleEffect(slot.selected ? 1 : 0.3).opacity(slot.selected ? 1 : 0)
            }
            .animation(.easeOut(duration: 0.18), value: slot.selected)
            .frame(width: rect.width, height: rect.height)
            .offset(x: rect.minX, y: rect.minY)
        }
        // As large as the card, from its top left corner: an offset moves a button but not the room it takes.
        .frame(width: card.width, height: card.height, alignment: .topLeading)
        .opacity(hovered ? 1 : 0)
        .animation(.easeOut(duration: 0.12), value: hovered)   // fades in and out as the island's cards' buttons do
    }
}
