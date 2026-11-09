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

    var body: some View {
        let stretch = CardRow.lit(at: lit, widths: widths)
        ZStack(alignment: .topLeading) {
            labels(ink: nil)
            ZStack(alignment: .topLeading) {
                AppAccent.color
                labels(ink: AppAccent.ink).offset(x: -stretch.x)
            }
            .frame(width: stretch.width, height: height, alignment: .topLeading)
            .clipped()
            .offset(x: stretch.x)
        }
        .frame(width: widths.reduce(0, +), height: height, alignment: .topLeading)
    }

    private func labels(ink: Color?) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(zip(cards, widths)), id: \.0.id) { card, width in
                // A name longer than its card is cut, with "…" at the end (nothing is measured for a step).
                ZoneCardLabel(card: card, ink: ink)
                    .frame(width: width, height: height)
            }
        }
        .frame(width: widths.reduce(0, +), height: height, alignment: .leading)
    }
}
