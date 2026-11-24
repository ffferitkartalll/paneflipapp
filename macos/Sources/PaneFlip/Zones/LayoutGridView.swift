import SwiftUI

/// A whole layout as a grid: over every zone of it, those of the screens beyond the edges too, the grid of the zone's windows, drawn by the view that draws the grid of
/// one zone (`ZoneWindowsView`): the same cards, buttons, frames and empty places. The grid scrolls from one screen of the layout to the next. A card that is carried is
/// drawn over everything. Nothing is drawn behind the cards: the desktop stays as it is. A click between the zones goes through to what is behind and closes the grid (the panel is the whole display, so that nothing cuts the shadows of the cards).
struct LayoutGridView: View {
    let model: LayoutGridModel

    var body: some View {
        ZStack(alignment: .topLeading) {
            ZStack(alignment: .topLeading) {
                // While the cards slide (opening, closing) only the zones in view are drawn: those of the screens beyond the edges would be redrawn at every step for nothing, and
                // their shadows would show in the last point of the screen. With the grid open (`offViewDrawn`) every zone is there, so that scrolling to another screen works as it did.
                ForEach(model.zones.filter { model.offViewDrawn.contains($0.id) || ($0.rect.maxX > model.shift && $0.rect.minX < model.shift + model.size.width) }) { zone in
                    ZoneWindowsView(model: zone.model)
                        .position(x: zone.rect.midX, y: zone.rect.midY)
                        .transition(.identity)
                }
            }
            .frame(width: model.size.width, height: model.size.height, alignment: .topLeading)
            .offset(x: -model.shift)
            .frame(width: model.size.width, height: model.size.height, alignment: .topLeading)
            if let ghost = model.carry { LayoutGridGhostView(ghost: ghost) }
        }
        .frame(width: model.size.width, height: model.size.height, alignment: .topLeading)
        .modifier(GridMakesRoom(model: model))
        // Between the zones the grid takes the mouse too (a click closes it, as one outside it does): the wheel and the fingers scroll it there as well. The window server lets the
        // mouse through the points of a window that are quite clear, so this is the least that is not (one step of the 8 bits of its opacity: nothing to the eye).
        .background { Color.black.opacity(1.0 / 255).contentShape(Rectangle()).onTapGesture { model.onClose() } }
        .offset(x: model.inset.x, y: model.inset.y)
        .frame(width: model.wholeSize.width, height: model.wholeSize.height, alignment: .topLeading)
        .overlay(alignment: .topLeading) {
            if model.room > 0 {
                LayoutGridSearchBar(search: model.search)
                    .frame(width: model.size.width, height: LayoutGridModel.searchBarHeight, alignment: .top)
                    .offset(x: model.inset.x, y: model.inset.y + model.blockTop)
                    .modifier(BarComesFromTop(model: model))
                    .frame(width: model.wholeSize.width, height: model.wholeSize.height, alignment: .topLeading)
                    .mask { IslandCutout(cover: model.islandCover) }
            }
        }
        .ignoresSafeArea()   // the panel lies under the menu bar and the notch: the safe area would push the grid down
    }
}
