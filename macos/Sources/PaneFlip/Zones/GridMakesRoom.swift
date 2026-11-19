import SwiftUI

/// Makes room for the search bar over the grid as it opens (`LayoutGridModel.appear`): the zones grow lower, from where the pictures stand over their windows to a place below the
/// bar. The value is read here, in this small body, so that only this is worked out at every step of the slide.
struct GridMakesRoom: ViewModifier {
    let model: LayoutGridModel

    func body(content: Content) -> some View {
        content
            .scaleEffect(x: 1, y: 1 - (1 - model.gridScale) * model.appear, anchor: UnitPoint(x: 0.5, y: model.size.height > 0 ? model.blockTop / model.size.height : 0))
            .offset(y: model.room * model.appear)
    }
}

/// Brings the search bar into the room made for it from the top edge of the display, as the grid opens (`LayoutGridModel.appear`): it is above the display, out of sight, while the
/// pictures are over their windows, and comes down with the same motion as the cards. Nothing else (no fade of its own) moves it, so that it cannot be left half way.
struct BarComesFromTop: ViewModifier {
    let model: LayoutGridModel

    func body(content: Content) -> some View {
        content.offset(y: -(1 - model.appear) * (model.inset.y + model.blockTop + LayoutGridModel.searchBarHeight + 24))
    }
}
