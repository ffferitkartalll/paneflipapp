import AppKit
import SwiftUI

/// One card of the grid of a zone's windows: the picture of the window (the glyph of its app where it has none: an app that is not open), with its title at the top and,
/// on the card under the pointer, the buttons of the island's cards.
struct ZoneWindowsCard: View {
    let model: ZoneWindowsModel
    let card: IslandWindow
    /// The size of the card: the same for every card, an app that is not open too. The picture of a window is scaled to it, not kept to its own shape.
    let size: CGSize
    @State private var hoveredButton: IslandButton?

    /// As large as the picture of the app on a card of the island's row: never large on a large card.
    private static func glyphSide(in size: CGSize) -> CGFloat { min(32, max(14, min(size.width, size.height) * 0.4)) }

    var body: some View {
        let picture = model.pictures[card.id]
        let radius = picture.map { $0.cornerRadius * size.width / max($0.frame.width, 1) } ?? 8
        ZStack(alignment: .topLeading) {
            if let picture {
                Image(decorative: picture.image, scale: 1).resizable().interpolation(.high).frame(width: size.width, height: size.height)
            } else {
                RoundedRectangle(cornerRadius: radius).fill(.white.opacity(0.1))
                if let glyph = card.glyph {
                    Image(nsImage: glyph).renderingMode(.template).resizable().interpolation(.high).scaledToFit()
                        .foregroundStyle(.white.opacity(0.5))
                        .frame(width: Self.glyphSide(in: size), height: Self.glyphSide(in: size))
                        .frame(width: size.width, height: size.height)
                }
            }
            title
            buttons
        }
        .frame(width: size.width, height: size.height)
        .clipShape(RoundedRectangle(cornerRadius: radius))
        // The edge and the shadow macOS gives a window that is not in focus, measured on one: a light line of 1 point inside the edge, a dark one outside it, and a shadow
        // (black at half, blurred 16, 5 points lower). They come with the cards: over its window the picture must not differ from it.
        .overlay { RoundedRectangle(cornerRadius: radius).strokeBorder(.white.opacity(0.08 * model.appear), lineWidth: 1) }
        .overlay { RoundedRectangle(cornerRadius: radius + 1).strokeBorder(.black.opacity(0.85 * model.appear), lineWidth: 1).padding(-1) }
        // The shadow is cast by a plain shape behind the card, not by the picture: blurring a large picture again at every step of the slide made the grid late in showing.
        .background { RoundedRectangle(cornerRadius: radius).fill(.black).shadow(color: .black.opacity(0.5 * model.appear), radius: 16, y: 5) }
        // Two frames in the accent colour, which come and go softly (and with the cards: over its window the picture must not differ from it): the card with the focus
        // (the window in front) has the thickness of the frame that shows where the focus went between zones, the card to be chosen (under the pointer, or where the arrow keys
        // went) twice that: where the focus is, and where a click or Return would send it, are always told apart.
        .overlay {
            let focused = model.highlighted == card.id, pointed = model.pointed == card.id && model.carried == nil
            RoundedRectangle(cornerRadius: radius).strokeBorder(AppAccent.color, lineWidth: pointed ? 2 * ZoneFlash.lineWidth : ZoneFlash.lineWidth)
                .opacity(model.appear * (focused || pointed ? 1 : 0))
                .animation(.easeOut(duration: 0.15), value: focused)
                .animation(.easeOut(duration: 0.15), value: pointed)
        }
        .onContinuousHover { phase in
            switch phase {
            case .active:
                if model.hovered != card.id { model.hovered = card.id }
                if model.pointed != card.id { model.pointed = card.id }
            case .ended:
                if model.hovered == card.id { model.hovered = nil }
                if model.pointed == card.id { model.pointed = nil }   // an arrow key may have taken it to another card meanwhile: that one stays
            }
        }
    }

    private var buttonsShown: Bool { model.appear >= 1 && model.hovered == card.id && model.carried == nil && card.hasButtons }

    /// The title of the window, over the top of its picture, between the buttons of the card (a narrow card shows it only while the buttons do not).
    private var title: some View {
        let rects = IslandCardAction.rects(in: size, among: card.actions).map(\.rect)
        let room = size.width - 2 * ((rects.filter { $0.midX < size.width / 2 }.map(\.maxX).max() ?? 4) + 6)
        let shown = room >= 60 || !buttonsShown
        return Text(verbatim: card.caption)
            .font(Font(NSFont.menuBarFont(ofSize: 0)))
            .foregroundStyle(.white)
            .lineLimit(1)
            .truncationMode(.tail)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(Capsule().fill(.black.opacity(0.55)))
            .frame(maxWidth: shown && buttonsShown ? max(room, 0) : max(size.width - 16, 0))
            .frame(width: size.width, alignment: .top)
            .padding(.top, 4)
            .opacity(shown && model.appear >= 1 ? 1 : 0)
            .animation(.easeOut(duration: 0.12), value: shown && model.appear >= 1)
    }

    private static func fill(hover: Bool) -> Color { .black.opacity(hover ? 0.85 : 0.6) }

    /// The buttons of the card under the pointer, as the cards of the island's row have them.
    private var buttons: some View {
        ZStack(alignment: .topLeading) {
            ForEach(IslandCardAction.rects(in: size, among: card.actions), id: \.action) { item in
                Image(systemName: item.action.symbol).resizable().scaledToFit().fontWeight(.bold).foregroundStyle(.white)
                    .frame(width: item.rect.width * 0.5, height: item.rect.height * 0.5)
                    .frame(width: item.rect.width, height: item.rect.height)
                    .background(Circle().fill(Self.fill(hover: hoveredButton == .card(item.action, card.id))))
                    .contentShape(Circle())
                    .onHover { hoveredButton = $0 ? .card(item.action, card.id) : (hoveredButton == .card(item.action, card.id) ? nil : hoveredButton) }
                    .onTapGesture { model.onPerform(item.action, card) }
                    .offset(x: item.rect.minX, y: item.rect.minY)
            }
            let rect = IslandCardAction.selectRect(in: size)
            ZStack {
                Circle().fill(Self.fill(hover: hoveredButton == .select(card.id)))
                Image(systemName: "checkmark").resizable().scaledToFit().fontWeight(.bold).foregroundStyle(.white)
                    .frame(width: rect.width * 0.5, height: rect.height * 0.5)
                    .scaleEffect(card.selected ? 1 : 0.3).opacity(card.selected ? 1 : 0)
            }
            .frame(width: rect.width, height: rect.height)
            .contentShape(Circle())
            .onHover { hoveredButton = $0 ? .select(card.id) : (hoveredButton == .select(card.id) ? nil : hoveredButton) }
            .onTapGesture { model.onToggleStart(card) }
            .offset(x: rect.minX, y: rect.minY)
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .opacity(buttonsShown ? 1 : 0)
        .animation(.easeOut(duration: 0.12), value: buttonsShown)
    }
}
