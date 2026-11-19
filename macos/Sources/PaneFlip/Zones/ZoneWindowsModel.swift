import AppKit
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
    /// (The shadow of a card is blurred 16 points and 5 lower: it reaches about 40 points past the card's edge, so the room is more than that.)
    static let shadowRoom: CGFloat = 64
    /// Where the zone lies in a panel that is larger than it (the whole display, so that nothing cuts the shadows of the cards), and the size of that panel. Zero: the panel is
    /// the zone with `shadowRoom` on every side (the grid of the whole layout lays the zones out itself).
    var inset: CGPoint = .zero
    var wholeSize: CGSize = .zero
    var size: CGSize = .zero
    var gap: CGFloat = 0
    /// Where each window stood in the zone when the grid opened, in the room of the zone: its picture goes from there to its card, and back.
    var origins: [String: CGRect] = [:]
    /// The card whose picture lies over the others while they fly: the window in front, or, as the grid closes, the one chosen.
    var front: String?
    /// 0 with the pictures over their windows, 1 with the cards in their places: moved as the grid opens and closes.
    var appear: CGFloat = 0 { didSet { settled = appear >= 1 } }
    /// The cards are in their places: what changes only then reads this, not `appear`, so it is not worked out at every step of the slide.
    private(set) var settled = false
    /// The cards are on their way (the grid of the whole layout opening, closing or led by the fingers): the grid takes no pointer, so that nothing is hit-tested at every step.
    var sliding = false
    /// The card the pointer is on.
    var hovered: String?
    /// The card that has the focus: the window in front of the zone. It has a frame in the accent colour, which stays on it while the cards are gone through.
    var highlighted: String?
    /// The card a click, or Return, chooses: the one the pointer is on, or the arrow keys went to (they go on from it, from the card with the focus at first). Its frame is
    /// twice as thick as the one of the card with the focus.
    var pointed: String? { didSet { if pointed != oldValue { onPointed() } } }
    /// In the grid of the whole layout: whether any zone of it has a card to be chosen. While none has, the card with the focus is the one (it has the thicker frame too); nil in the grid of one zone, where it is the zone's own mark.
    var chosenAnywhere: Bool?
    /// The card the mouse carries, and where its middle is, in the room of the zone.
    var carried: String?
    var carriedAt: CGPoint = .zero

    /// Where the cards stand, in the order of `cards`, and the places of the grid they leave empty.
    var cells: [CGRect] { ZoneGrid.cells(count: cards.count, in: size, gap: gap) }
    var emptyCells: [CGRect] { ZoneGrid.emptyCells(count: cards.count, in: size, gap: gap) }

    /// Carries the cards instead of this grid (the grid of the whole layout), and whether this grid follows the focus: its card with the focus is marked, and the mark
    /// stays on a card of it (a zone of the grid of the whole layout that has not the focus has no mark).
    @ObservationIgnored weak var carrier: ZoneCardCarrying?
    @ObservationIgnored var tracksFocus = true

    // What the owner does with what is done in the grid.
    /// The glyphs of the apps as pictures made once: an `NSImage` is turned into a picture again at every step of a slide when it is drawn as it is.
    @ObservationIgnored private var glyphPictures: [ObjectIdentifier: (glyph: NSImage, picture: CGImage)] = [:]   // the glyph is kept, so that its identity is not reused
    func glyphPicture(_ glyph: NSImage) -> CGImage? {
        let key = ObjectIdentifier(glyph)
        if let known = glyphPictures[key] { return known.picture }
        guard let made = glyph.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        glyphPictures[key] = (glyph, made)
        return made
    }
    @ObservationIgnored private var titles: [String: CGImage] = [:]
    /// The title of a card as a picture made once, for the caption and the width in `key`.
    func titlePicture<V: View>(_ key: String, content: () -> V) -> CGImage? {
        if let kept = titles[key] { return kept }
        let made = MainActor.assumeIsolated { () -> CGImage? in
            let renderer = ImageRenderer(content: content())
            renderer.scale = 2
            return renderer.cgImage
        }
        if titles.count > 64 { titles = [:] }
        titles[key] = made
        return made
    }
    @ObservationIgnored var outlines: (places: [CGRect], size: CGSize, picture: CGImage)?
    @ObservationIgnored var onPointed: () -> Void = {}
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
            carrier?.carryBegan(card, from: self)
        }
        if let carrier { return carrier.carryMoved() }
        var still = Transaction()
        still.disablesAnimations = true
        withTransaction(still) { carriedAt = CGPoint(x: point.x - grab.x, y: point.y - grab.y) }
        // The place is the one the pointer is over (an empty cell is the end), as in the grid of a whole layout.
        guard let to = ZoneGrid.place(at: point, count: cards.count, in: size, gap: gap), to != from else { return }
        onMove(card, cards[to])
    }

    /// The mouse is let go: a card held where it was is chosen; a carried one goes to its place.
    func dropped(_ card: IslandWindow) {
        guard carried != nil else { return onChoose(card) }
        if let carrier { return carrier.carryEnded(card, from: self) }   // the grid of the whole layout lands the card itself
        carried = nil   // from where the mouse let it go to its place (where `cells` say)
    }
}
