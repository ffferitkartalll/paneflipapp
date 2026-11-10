import PaneFlipCore
import SwiftUI

/// What the notch shows inside, at rest, grown and expanded, as one picture that moves between them: the notch is cut into a part for each open window of its zone, growing
/// turns each part into the card of its window (`cells`: as wide as the part at first, as wide as the card at the end, with `grow` from 0 to 1 between), the part of the window
/// in front into the lit card, and expanding turns each card into the card of the island's row (`ZoneNotchCard`, `expand` from 0 to 1), the apps that are not open coming in
/// between them. Made the way the open island makes its row, so that a step costs the main thread next to nothing however quickly steps follow: the cards are drawn once and
/// never move; the lit card is an accent rectangle that only changes its place and its width (to the card it stands on, `CardRow.lit`), and carries a copy of the row in the
/// dark colour that moves the other way as much, so that the copy stands still on the screen and shows only through the lit card. Nothing is masked or drawn anew.
struct ZoneNotchRow: View {
    /// The open windows, or, expanded, every slot of the zone.
    let cards: [IslandWindow]
    /// How wide each card is when the notch has grown: as wide as its name, up to as wide as the open island writes one (`ZoneNotches.showSwitch`); 0 for an app that is not open.
    let widths: [CGFloat]
    /// How wide each part is now, between the equal parts of the notch at rest, the cards and the cards of the expanded notch.
    let cells: [CGFloat]
    /// How tall the compact row is.
    let height: CGFloat
    /// Which part or card is lit: its place among them, between two while the fingers lead.
    let lit: CGFloat
    /// How much the accent colour shows: 0 at rest, 1 with the pointer on the notch, and grown.
    let lift: CGFloat
    /// 0 for the notch at rest, 1 for the grown one; and 0 for the compact row, 1 for the expanded notch.
    let grow: CGFloat
    let expand: CGFloat
    /// How wide a card of the expanded notch is.
    let cardWidth: CGFloat
    /// The card the pointer is on: it is tinted unless it is the lit one.
    let hovered: Int?
    let hoveredButton: IslandButton?
    /// The card the mouse carries and where its middle is: it floats there, over the row, and leaves its place empty.
    let carried: String?
    let carriedX: CGFloat
    /// The pointer is on the button at the end of the row that expands it (`ZoneNotches`): as wide as the row is tall.
    let moreHovered: Bool

    var body: some View {
        let stretch = CardRow.lit(at: lit, widths: cells)
        // The cards are as tall as the compact row's, then as tall as the island's, with the line of the title.
        let tall = height + (ZoneNotchExpanded.cardHeight(width: cardWidth) - height) * expand
        // The card in front is the one carried: its lit fill goes with it.
        let litCarried = carried.flatMap { id in cards.firstIndex { $0.id == id } }.map { abs(CGFloat($0) - lit) < 0.5 } ?? false
        ZStack(alignment: .topLeading) {
            // Each card has a tint of its own that fades in and out, as the cards of the open island's row do: nothing slides from one card to the next.
            HStack(spacing: 0) {
                ForEach(Array(cells.enumerated()), id: \.offset) { index, width in
                    Rectangle().fill(AppAccent.color.opacity(index == hovered && abs(CGFloat(index) - lit) > 0.5 && carried == nil ? 0.25 : 0))
                        .frame(width: width, height: tall)
                        .animation(.easeOut(duration: 0.12), value: hovered)
                }
            }
            
            elements(ink: nil, tall: tall)
            ZStack(alignment: .topLeading) {
                AppAccent.color
                elements(ink: AppAccent.ink, tall: tall).offset(x: -stretch.x)
            }
            .frame(width: stretch.width, height: tall, alignment: .topLeading)
            .clipped()
            .offset(x: stretch.x)
            .opacity(litCarried ? 0 : lift)
            if expand > 0 { expandedCards(tall: tall).opacity(expand) }
        }
        .overlay(alignment: .topLeading) {
            // The carried card itself floats over the row, as it is drawn there: lit if it is the one in front, else plain on the notch's own colour with its hover tint.
            if let carried, let index = cards.firstIndex(where: { $0.id == carried }), cells.indices.contains(index) {
                tile(index, ink: litCarried ? AppAccent.ink : nil, tall: tall)
                    .background {
                        // Square corners. A card that is not in front keeps the tint it had under the pointer.
                        ZStack {
                            Rectangle().fill(litCarried ? AppAccent.color : Color(nsColor: .windowBackgroundColor))
                            if !litCarried { Rectangle().fill(AppAccent.color.opacity(0.25)) }
                        }
                    }
                    .offset(x: carriedX - cells[index] / 2)
            }
        }
        .overlay(alignment: .topLeading) {
            // The button at the end of the row: only its picture. It comes with the cards and goes as the notch expands.
            Image(systemName: "ellipsis").resizable().scaledToFit().fontWeight(.bold)
                .foregroundStyle(Color.primary.opacity(moreHovered ? 1 : 0.6))
                .frame(width: height * 0.5, height: height * 0.5)
                .frame(width: height, height: height)
                .background(AppAccent.color.opacity(moreHovered ? 0.25 : 0))
                .offset(x: cells.reduce(0, +))
                .opacity(grow * (1 - expand))
                .animation(.easeOut(duration: 0.12), value: moreHovered)
        }
    }

    /// The cards of the expanded notch, each as wide as its part is now, the title under it.
    private func expandedCards(tall: CGFloat) -> some View {
        let starts = cells.indices.map { cells[..<$0].reduce(0, +) }
        return ZStack(alignment: .topLeading) {
            ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                ZoneNotchCard(slot: card, width: cells[index], cardWidth: cardWidth, hovered: index == hovered && carried == nil, hoveredButton: hoveredButton)
                    .frame(width: cells[index], height: tall, alignment: .top)
                    .offset(x: starts[index])
            }
        }
    }

    /// The picture and the title of every card. The compact row's own, as the notch grows: the picture in front of the title, the two centred in the card. As it expands they go
    /// where the card of the island's row has them, the picture and the title one above the other, centred in the card, and grow or shrink on the way; the cards of apps that
    /// are not open have them only then. The card in front is dark (`ink`) where it is lit.
    private func elements(ink: Color?, tall: CGFloat) -> some View {
        let starts = cells.indices.map { cells[..<$0].reduce(0, +) }
        return ZStack(alignment: .topLeading) {
            ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                tile(index, ink: ink, tall: tall).opacity(card.id == carried ? 0 : 1).offset(x: starts[index])
            }
        }
        .frame(width: cells.reduce(0, +), height: tall, alignment: .topLeading)
    }

    /// The picture and the title of one card, in the room of its part.
    private func tile(_ index: Int, ink: Color?, tall: CGFloat) -> some View {
        let card = cards[index]
        let picture = ZoneNotchExpanded.pictureSize(width: cardWidth)
        let bigIcon = min(32, max(14, min(picture.width, picture.height) * 0.4))
        // Expanded, the picture and the title are one group, centred in the card, the whole of it.
        let group = bigIcon + ZoneNotchExpanded.groupGap + ZoneNotchExpanded.titleHeight
        let groupTop = (ZoneNotchExpanded.cardHeight(width: cardWidth) - group) / 2
        func mix(_ from: CGFloat, _ to: CGFloat) -> CGFloat { from + (to - from) * expand }
        let open = card.windowID != nil
        let style: AnyShapeStyle = ink.map { AnyShapeStyle($0.opacity(open ? 1 : 0.5)) } ?? AnyShapeStyle(open ? .secondary : .tertiary)
        let compact = widths[index], sideRoom = (cells[index] - compact) / 2
        let nameWidth = max(compact - ZoneCardLabel.chrome(of: card), 0)
        return ZStack(alignment: .topLeading) {
            if let glyph = card.glyph {
                let side = mix(ZoneCardLabel.icon, bigIcon)
                let iconX = mix(sideRoom + ZoneCardLabel.padding + ZoneCardLabel.badgeRoom(of: card) + ZoneCardLabel.icon / 2, cells[index] / 2) - side / 2, iconY = mix(tall / 2, groupTop + bigIcon / 2) - side / 2
                Image(nsImage: glyph).renderingMode(.template).resizable().interpolation(.high).antialiased(true).scaledToFit()
                    .foregroundStyle(style)
                    .frame(width: side, height: side)
                    .offset(x: iconX, y: iconY)
                // The Dock's badge: left of the icon as the notch is compact, at the remove button's place on the card as it expands, one badge moving there;
                // the buttons of the card under the pointer take its place.
                if let text = card.badgeText {
                    let buttonsShow = index == hovered && carried == nil && card.hasButtons
                    let target = IslandCardAction.rects(in: picture, among: [.remove]).first?.rect ?? .zero
                    let small = ZoneCardLabel.badgeHeight / target.width
                    let compactX = sideRoom + ZoneCardLabel.padding + ZoneCardLabel.badgeWidth(of: card) / 2
                    let centre = CGPoint(x: mix(compactX, (cells[index] - picture.width) / 2 + target.midX), y: mix(tall / 2, target.midY))
                    ZoneNotchBadge(text: text, base: target.width, scale: mix(small, 1))
                        .position(centre)
                        .transition(.opacity)
                        .opacity(buttonsShow ? 1 - expand : 1)
                        .animation(.easeOut(duration: 0.12), value: buttonsShow)   // gives way to the buttons as the island's badge does
                }
            }
            let textWidth = mix(nameWidth, cardWidth)
            Text(verbatim: card.caption).font(Font(ZoneCardLabel.font)).lineLimit(1).multilineTextAlignment(.center)
                .foregroundStyle(style)
                .frame(width: textWidth, height: ZoneNotchExpanded.titleHeight)
                .offset(x: mix(sideRoom + ZoneCardLabel.padding + ZoneCardLabel.badgeRoom(of: card) + (card.glyph != nil ? ZoneCardLabel.icon + ZoneCardLabel.spacing : 0) + nameWidth / 2, cells[index] / 2) - textWidth / 2,
                        y: mix(tall / 2, groupTop + bigIcon + ZoneNotchExpanded.groupGap + ZoneNotchExpanded.titleHeight / 2) - ZoneNotchExpanded.titleHeight / 2)
        }
        .frame(width: cells[index], height: tall, alignment: .topLeading)
        .opacity((open ? grow : expand))
    }
}
