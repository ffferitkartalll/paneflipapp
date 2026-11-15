import SwiftUI

/// The windows of one zone as a grid of pictures laid over the zone, as Mission Control lays out windows over the screen: the zone dimmed, each picture sliding from over
/// its window into its place in the grid (and back). A click on a card chooses it, a card can be carried to another place, a click on the dimmed zone closes it.
struct ZoneWindowsView: View {
    let model: ZoneWindowsModel

    var body: some View {
        let cells = model.cells, appear = model.appear, whole = model.wholeSize != .zero
        let middle = CGPoint(x: model.size.width / 2, y: model.size.height / 2)
        ZStack(alignment: .topLeading) {
            // Nothing is drawn behind the cards; this takes a click between them (a window that is fully clear lets the mouse through, so not quite clear).
            Color.black.opacity(0.01)
                .contentShape(Rectangle())
                .onTapGesture { model.onClose() }
            // Every place of the grid has a dashed line round it, behind the card that stands in it: it comes with the cards, and stays where it is as the cards move (the
            // cards do not take it along; it is covered by the card that comes, and shows again when the card goes).
            // The one the carried card would be put down in is stronger, and stays so until the card is carried to another place.
            let target = model.carried.flatMap { id in model.cards.firstIndex { $0.id == id } }
            ForEach(Array((cells + model.emptyCells).enumerated()), id: \.offset) { offset, cell in
                let chosen = offset == target
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(.white.opacity(chosen ? 1 : 0.45), style: StrokeStyle(lineWidth: chosen ? 3 : 1.5, dash: [8, 6]))
                    .animation(.easeOut(duration: 0.2), value: chosen)
                    .frame(width: cell.width, height: cell.height)
                    .position(x: cell.midX, y: cell.midY)
                    .animation(nil, value: model.cards.count)
                    .transition(.identity)
                    .opacity(appear)
                    .allowsHitTesting(false)
            }
            ForEach(Array(model.cards.enumerated()), id: \.element.id) { index, card in
                if cells.indices.contains(index) {
                    let cell = cells[index], carried = model.carried == card.id
                    let size = cell.size
                    // From over its window to the middle of its cell; a card with no window comes out of the middle of the zone.
                    let from = model.origins[card.id]
                    let start = from.map { CGPoint(x: $0.midX, y: $0.midY) } ?? middle
                    // The card is scaled to the window's shape and size at first (not alike along both sides: a card is not quite the shape of the zone).
                    let startScale = CGSize(width: from.map { size.width > 0 ? $0.width / size.width : 1 } ?? 0.3, height: from.map { size.height > 0 ? $0.height / size.height : 1 } ?? 0.3)
                    let place = CGPoint(x: start.x + (cell.midX - start.x) * appear, y: start.y + (cell.midY - start.y) * appear)
                    ZoneWindowsCard(model: model, card: card, size: size)
                        .scaleEffect(x: carried ? 1.04 : startScale.width + (1 - startScale.width) * appear, y: carried ? 1.04 : startScale.height + (1 - startScale.height) * appear)
                        .animation(.easeOut(duration: 0.15), value: carried)   // the card grows as it is taken up, not at once
                        .opacity(carried && model.carrier != nil ? 0 : 1)   // the grid of the whole layout draws a card it carries itself
                        .position(carried ? model.carriedAt : place)
                        .zIndex(carried ? 2 : (card.id == model.front ? 1 : 0))
                        .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .named("zone"))
                            .onChanged { model.dragged(card, from: $0.startLocation, to: $0.location) }
                            .onEnded { _ in withAnimation(.smooth(duration: 0.25)) { model.dropped(card) } })
                }
            }
        }
        .coordinateSpace(name: "zone")
        .frame(width: model.size.width, height: model.size.height)
        .padding(ZoneWindowsModel.shadowRoom)
        .frame(width: model.size.width + 2 * ZoneWindowsModel.shadowRoom, height: model.size.height + 2 * ZoneWindowsModel.shadowRoom, alignment: .topLeading)
        .offset(x: whole ? model.inset.x - ZoneWindowsModel.shadowRoom : 0, y: whole ? model.inset.y - ZoneWindowsModel.shadowRoom : 0)
        .frame(width: whole ? model.wholeSize.width : nil, height: whole ? model.wholeSize.height : nil, alignment: .topLeading)
        .ignoresSafeArea()   // a panel that is the whole display lies under the menu bar and the notch: the safe area would push the grid down
    }
}
