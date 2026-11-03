import SwiftUI

/// The picture of the carried card: only the app's glyph in a round button, as the card's own buttons are (no frame, no title).
struct CardGhostView: View {
    let model: CardGhostModel

    var body: some View {
        if let glyph = model.card?.glyph {
            let icon = model.icon
            Image(nsImage: glyph).renderingMode(.template).resizable().scaledToFit().foregroundStyle(.white)
                .frame(width: icon, height: icon)
                .frame(width: icon * 1.6, height: icon * 1.6)
                .background(Circle().fill(Color.black))
        }
    }
}
