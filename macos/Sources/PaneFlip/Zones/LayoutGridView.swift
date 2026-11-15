import SwiftUI

/// A whole layout as a grid: over every zone of it, those of the screens beyond the edges too, the grid of the zone's windows, drawn by the view that draws the grid of
/// one zone (`ZoneWindowsView`): the same cards, buttons, frames and empty places. The grid scrolls from one screen of the layout to the next. A card that is carried is
/// drawn over everything. Nothing is drawn behind the cards: the desktop stays as it is. A click between the zones goes through to what is behind and closes the grid (the panel is the whole display, so that nothing cuts the shadows of the cards).
struct LayoutGridView: View {
    let model: LayoutGridModel

    var body: some View {
        ZStack(alignment: .topLeading) {
            ZStack(alignment: .topLeading) {
                ForEach(model.zones) { zone in
                    ZoneWindowsView(model: zone.model)
                        .position(x: zone.rect.midX, y: zone.rect.midY)
                }
            }
            .frame(width: model.size.width, height: model.size.height, alignment: .topLeading)
            .offset(x: -model.shift)
            .frame(width: model.size.width, height: model.size.height, alignment: .topLeading)
            if let ghost = model.carry { LayoutGridGhostView(ghost: ghost) }
        }
        .frame(width: model.size.width, height: model.size.height, alignment: .topLeading)
        .offset(x: model.inset.x, y: model.inset.y)
        .frame(width: model.wholeSize.width, height: model.wholeSize.height, alignment: .topLeading)
        .ignoresSafeArea()   // the panel lies under the menu bar and the notch: the safe area would push the grid down
    }
}
