import PaneFlipCore
import SwiftUI

/// The grown notch's row of open windows, made the way the open island makes its row, so that a step costs the main thread next to nothing however quickly steps
/// follow: the cards are drawn once and never move; the lit card is an accent rectangle that only changes its place and its width (to the card it stands on,
/// `CardRow.lit`), and carries a copy of the row in the dark colour that moves the other way as much, so that the copy stands still on the screen and shows only
/// through the lit card. Nothing is masked or drawn anew.
struct ZoneNotchRow: View {
    let cards: [IslandWindow]
    /// How wide each card is: as wide as its name, up to as wide as the open island writes one (`ZoneNotches.showSwitch`).
    let widths: [CGFloat]
    let height: CGFloat
    /// Which card is lit: its place among them, between two while the fingers lead.
    let lit: CGFloat
    /// The card the pointer is on: it is tinted unless it is the lit one.
    let hovered: Int?
    /// The card the mouse carries and where its middle is: it floats there, over the row, and leaves its place empty.
    let carried: String?
    let carriedX: CGFloat

    var body: some View {
        let stretch = CardRow.lit(at: lit, widths: widths)
        // The card in front is the one carried: its lit fill goes with it.
        let litCarried = carried.flatMap { id in cards.firstIndex { $0.id == id } }.map { abs(CGFloat($0) - lit) < 0.5 } ?? false
        ZStack(alignment: .topLeading) {
            // Each card has a tint of its own that fades in and out, as the cards of the open island's row do: nothing slides from one card to the next.
            HStack(spacing: 0) {
                ForEach(Array(widths.enumerated()), id: \.offset) { index, width in
                    Rectangle().fill(AppAccent.color.opacity(index == hovered && abs(CGFloat(index) - lit) > 0.5 && carried == nil ? 0.25 : 0))
                        .frame(width: width, height: height)
                        .animation(.easeOut(duration: 0.12), value: hovered)
                }
            }
            labels(ink: nil)
            ZStack(alignment: .topLeading) {
                AppAccent.color
                labels(ink: AppAccent.ink).offset(x: -stretch.x)
            }
            .frame(width: stretch.width, height: height, alignment: .topLeading)
            .clipped()
            .offset(x: stretch.x)
            .opacity(litCarried ? 0 : 1)
        }
        .overlay(alignment: .topLeading) {
            // The carried card itself floats over the row, as it is drawn there: lit if it is the one in front, else plain on the notch's own colour with its hover tint.
            if let carried, let index = cards.firstIndex(where: { $0.id == carried }), widths.indices.contains(index) {
                ZoneCardLabel(card: cards[index], ink: litCarried ? AppAccent.ink : nil)
                    .frame(width: widths[index], height: height)
                    .background {
                        // Square corners. A card that is not in front keeps the tint it had under the pointer.
                        ZStack {
                            Rectangle().fill(litCarried ? AppAccent.color : Color(nsColor: .windowBackgroundColor))
                            if !litCarried { Rectangle().fill(AppAccent.color.opacity(0.25)) }
                        }
                    }
                    .offset(x: carriedX - widths[index] / 2)
            }
        }
        .frame(width: widths.reduce(0, +), height: height, alignment: .topLeading)
    }

    private func labels(ink: Color?) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(zip(cards, widths)), id: \.0.id) { card, width in
                // A name longer than its card is cut, with "…" at the end (nothing is measured for a step).
                ZoneCardLabel(card: card, ink: ink)
                    .frame(width: width, height: height)
                    .opacity(card.id == carried ? 0 : 1)
            }
        }
        .frame(width: widths.reduce(0, +), height: height, alignment: .leading)
    }
}
