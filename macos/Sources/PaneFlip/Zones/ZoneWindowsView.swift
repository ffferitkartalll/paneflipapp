import SwiftUI

/// The windows of one zone as a grid of pictures laid over the zone, as Mission Control lays out windows over the screen: the zone dimmed, each picture sliding from over
/// its window into its place in the grid (and back). A click on a card chooses it, a card can be carried to another place, a click on the dimmed zone closes it.
struct ZoneWindowsView: View {
    let model: ZoneWindowsModel

    var body: some View {
        let cells = model.cells, whole = model.wholeSize != .zero
        ZStack(alignment: .topLeading) {
            // Nothing is drawn behind the cards; this takes a click between them (a window that is fully clear lets the mouse through, so not quite clear).
            Color.black.opacity(0.01)
                .contentShape(Rectangle())
                .onTapGesture { model.onClose() }
            // Every place of the grid has a dashed line round it, behind the card that stands in it: it comes with the cards, and stays where it is as the cards move (the
            // cards do not take it along; it is covered by the card that comes, and shows again when the card goes).
            // The one the carried card would be put down in is stronger, and stays so until the card is carried to another place.
            let target = model.carried.flatMap { id in model.cards.firstIndex { $0.id == id } }
            // The lines fade in and out with the grid's opening, as the cards of apps that are not open do (`CardGlide`): in their place, with `ZoneWindowsModel.appear`. Drawn once as
            // a picture (`outlinePicture`), except the place the carried card would be put down in, which is stronger and eases to it.
            let places = cells + model.emptyCells
            ZStack(alignment: .topLeading) {
                if let picture = model.outlinePicture(of: places.enumerated().filter { $0.offset != target }.map(\.element)) {
                    Image(decorative: picture, scale: 2).resizable().frame(width: model.size.width, height: model.size.height)
                        .modifier(AppearOpacity(model: model))   // on the picture itself: opacity on the whole group would be drawn in a pass of its own
                }
                if let target, places.indices.contains(target) {
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(.white, style: StrokeStyle(lineWidth: 3, dash: [8, 6]))
                        .frame(width: places[target].width, height: places[target].height)
                        .position(x: places[target].midX, y: places[target].midY)
                        .modifier(AppearOpacity(model: model))
                        .transition(.opacity)
                }
            }
            .animation(.easeOut(duration: 0.2), value: target)
            .animation(nil, value: model.cards.count)
            .frame(width: model.size.width, height: model.size.height, alignment: .topLeading)
            .allowsHitTesting(false)
            ForEach(Array(model.cards.enumerated()), id: \.element.id) { index, card in
                if cells.indices.contains(index) {
                    let cell = cells[index], carried = model.carried == card.id
                    let size = cell.size
                    // From over its window to the middle of its cell; a card with no window is not seen to move or grow: it comes into being in its cell, fading in.
                    ZoneWindowsCard(model: model, card: card, size: size)
                        .modifier(CardGlide(model: model, cell: cell, from: model.origins[card.id], carried: carried, hidden: carried && model.carrier != nil))
                        .opacity(model.matching.map { $0.contains(card.id) ? 1 : 0.3 } ?? 1)
                        .animation(.easeOut(duration: 0.15), value: model.matching)
                        .zIndex(carried ? 3 : (card.id == model.front ? 2 : (card.windowID == nil ? 0 : 1)))   // a card of an app that is not open lies behind the open ones as they slide
                        .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .named("zone"))
                            .onChanged { model.dragged(card, from: $0.startLocation, to: $0.location) }
                            .onEnded { _ in withAnimation(.smooth(duration: 0.25)) { model.dropped(card) } })
                }
            }
        }
        .coordinateSpace(name: "zone")
        .modifier(SlidingHitTesting(model: model))   // the hover is worked out again once the cards rest
        .frame(width: model.size.width, height: model.size.height)
        .padding(ZoneWindowsModel.shadowRoom)
        .frame(width: model.size.width + 2 * ZoneWindowsModel.shadowRoom, height: model.size.height + 2 * ZoneWindowsModel.shadowRoom, alignment: .topLeading)
        .offset(x: whole ? model.inset.x - ZoneWindowsModel.shadowRoom : 0, y: whole ? model.inset.y - ZoneWindowsModel.shadowRoom : 0)
        .frame(width: whole ? model.wholeSize.width : nil, height: whole ? model.wholeSize.height : nil, alignment: .topLeading)
        .ignoresSafeArea()   // a panel that is the whole display lies under the menu bar and the notch: the safe area would push the grid down
    }
}
