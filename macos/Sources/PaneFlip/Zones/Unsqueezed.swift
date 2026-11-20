import SwiftUI

/// Draws what is drawn on a card at its own size where the whole layout's grid is drawn lower to make room for the search bar (`ZoneWindowsModel.squeeze`): it goes by the
/// grid's opening (`appear`) step by step, as the grid does, so that the app glyph, the title and the buttons of a card are not squeezed at any moment of the slide. It is drawn
/// about `anchor`: the middle for the glyph, which is in the middle of the card, the top for the title and the buttons, which stand along the top. The value is read here, in this
/// small body, so that only this is worked out at every step.
struct Unsqueezed: ViewModifier {
    let model: ZoneWindowsModel
    var anchor = UnitPoint.center

    func body(content: Content) -> some View {
        content.scaleEffect(x: 1, y: 1 / (1 - (1 - model.squeeze) * model.appear), anchor: anchor)
    }
}
