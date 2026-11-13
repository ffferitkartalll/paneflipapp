import CoreGraphics
import Foundation
import Observation
import PaneFlipCore
import SwiftUI

/// What the windows of one zone, laid out over it as a grid of pictures, show (`ZoneWindowsView`).
@Observable
final class ZoneWindowsModel {
    /// Every slot of the zone in the order of its cards: its windows and the apps of it that are not open.
    var cards: [IslandWindow] = []
    /// The picture of the card of each window (`IslandWindow.id`), when it has come.
    var pictures: [String: WindowPicture] = [:]
    /// The room of the zone, and the room between the cards (the one between zones).
    /// How far the panel reaches beyond the zone on every side, for the shadows of the cards at its edge.
    static let shadowRoom: CGFloat = 32
    var size: CGSize = .zero
    var gap: CGFloat = 0
    /// Where each window stood in the zone when the grid opened, in the room of the zone: its picture goes from there to its card, and back.
    var origins: [String: CGRect] = [:]
    /// The card whose picture lies over the others while they fly: the window in front, or, as the grid closes, the one chosen.
    var front: String?
    /// 0 with the pictures over their windows, 1 with the cards in their places: moved as the grid opens and closes.
    var appear: CGFloat = 0
    /// The card the pointer is on.
    var hovered: String?
    /// The card that has the focus: the window in front of the zone. It has a frame in the accent colour, which stays on it while the cards are gone through.
    var highlighted: String?
    /// The card a click, or Return, chooses: the one the pointer is on, or the arrow keys went to (they go on from it, from the card with the focus at first). Its frame is
    /// twice as thick as the one of the card with the focus.
    var pointed: String?
    /// The card the mouse carries, and where its middle is, in the room of the zone.
    var carried: String?
    var carriedAt: CGPoint = .zero

    /// Where the cards stand, in the order of `cards`.
    var cells: [CGRect] { ZoneGrid.cells(count: cards.count, in: size, gap: gap) }

    // What the owner does with what is done in the grid.
    @ObservationIgnored var onChoose: (IslandWindow) -> Void = { _ in }
    @ObservationIgnored var onPerform: (IslandCardAction, IslandWindow) -> Void = { _, _ in }
    @ObservationIgnored var onToggleStart: (IslandWindow) -> Void = { _ in }
    /// A card was carried to the place of another one.
    @ObservationIgnored var onMove: (IslandWindow, IslandWindow) -> Void = { _, _ in }
    @ObservationIgnored var onClose: () -> Void = {}

    /// An arrow key: the card to be chosen goes one card along the grid, as the pointer going to another card does.
    func movePointer(columns: Int, rows: Int) {
        guard !cards.isEmpty else { return }
        let current = (pointed ?? highlighted).flatMap { id in cards.firstIndex { $0.id == id } } ?? 0
        pointed = cards[ZoneGrid.moved(from: current, columns: columns, rows: rows, count: cards.count)].id
    }

    /// Return: the card to be chosen is chosen (the card with the focus, if there is none).
    func choosePointed() {
        if let card = cards.first(where: { $0.id == pointed }) ?? cards.first(where: { $0.id == highlighted }) ?? cards.first { onChoose(card) }
    }

    /// Where the mouse took the card, from its middle.
    @ObservationIgnored private var grab: CGPoint = .zero

    /// The mouse is down on `card` (at `start`) and is at `point`: a card is carried once the mouse has moved a little, and goes to the place it is over.
    func dragged(_ card: IslandWindow, from start: CGPoint, to point: CGPoint) {
        let cells = self.cells
        guard let from = cards.firstIndex(where: { $0.id == card.id }), cells.indices.contains(from) else { return }
        if carried == nil {
            guard hypot(point.x - start.x, point.y - start.y) >= 4 else { return }
            grab = CGPoint(x: start.x - cells[from].midX, y: start.y - cells[from].midY)
            carried = card.id
        }
        var still = Transaction()
        still.disablesAnimations = true
        withTransaction(still) { carriedAt = CGPoint(x: point.x - grab.x, y: point.y - grab.y) }
        guard let to = ZoneGrid.index(at: carriedAt, in: cells), to != from else { return }
        onMove(card, cards[to])
    }

    /// The mouse is let go: a card held where it was is chosen; a carried one goes to its place.
    func dropped(_ card: IslandWindow) {
        guard carried != nil else { return onChoose(card) }
        carried = nil   // from where the mouse let it go to its place (where `cells` say)
    }
}
