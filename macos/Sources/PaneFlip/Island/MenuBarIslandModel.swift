import Foundation
import Observation
import SwiftUI
import PaneFlipCore

/// What the island in the menu bar of one display shows: the little picture of the zones and the zone with the focus.
@Observable
final class MenuBarIslandModel {
    var glyph = ZoneGlyph(zones: [], screen: .zero, screenSize: .zero)
    private(set) var activeID: UUID?
    /// The zone that had the focus before, and how far the change to the new one has come (0 to 1): the lit zone fades over.
    private(set) var previousID: UUID?
    var blend: CGFloat = 1
    /// How far the frame of the screen is from where the glyph was drawn it: it slides along the strip while the layout scrolls.
    var outlineShift: CGFloat = 0
    /// How many times as large as at rest the picture is drawn (1 at rest; more while the pointer is on the island, when each zone also shows its name).
    /// The island then reaches below the menu bar.
    var zoom: CGFloat = 1
    /// The zoom of the open island: `MenuBarIslandView.hoverZoom`, or less when the picture would not fit the display.
    var openZoom: CGFloat = MenuBarIslandView.hoverZoom
    /// The pointer is on the island: it stands below the menu bar as one block.
    var expanded = false
    /// What the open island holds beyond the little picture (the numbers of the zones, the windows of a zone): shown while it is open, gone at once
    /// when it begins to shrink, so that none of it is seen on the shrinking background.
    var contentOpacity: CGFloat = 0
    var cellTexts: [UUID: String] = [:]
    /// The zone chosen in the picture by a click: its windows stand under the picture, in a frame while it is set.
    var windowsZone: UUID?
    /// The windows of that zone (they stay while the row closes, so that it fades instead of going at once).
    var windows: [IslandWindow] = []
    /// How far the fingers (or the wheel's turn) have led the windows from the one in front, in windows: positive brings the ones before it in.
    var windowsDrag: CGFloat = 0
    /// A zone on the screen has more than one card in its row: windows and apps that are not open count alike.
    var crowded = false
    var barHeight: CGFloat = 24
    /// 0 on a display without a notch.
    var notchWidth: CGFloat = 0
    /// Device pixels per point of the display: what the drawing is aligned to.
    var scale: CGFloat = 2
}

extension MenuBarIslandModel {
    /// The frame of the chosen zone's windows under the picture: as large as that zone is drawn in the open picture (never wider than it), and the line
    /// with the title of the window in front under it. The gap between the picture and the frame.
    var windowsGap: CGFloat { barHeight / 2 }
    /// The title under a card, and the line under that.
    var captionHeight: CGFloat { 30 }
    private var titleGap: CGFloat { windowsGap }   // the title stands as far from the frame as from the island's lower edge

    var windowsFrame: CGSize {
        guard let cell = glyph.cells.first(where: { $0.id == windowsZone }) else { return .zero }
        return CGSize(width: min(cell.rect.width * openZoom, glyph.size.width * openZoom), height: cell.rect.height * openZoom)
    }

    /// The room the row of cards has: as wide as the picture. The cards that are not in front share it when they do not fit with the width of the frame.
    var cardsFit: CGFloat { roomWidth * openZoom }

    /// The width the open island is laid out for, at rest size, with its picture in the middle: the picture itself, or, when a zone holds several cards and
    /// zones do not wait beyond both edges of the screen, at least as wide as it would be with a screen's width of them on both sides (the row of cards
    /// under the picture would be cramped in the width of the picture alone). With no zone holding several cards there is nothing to cramp.
    var roomWidth: CGFloat {
        let both = glyph.screen.minX > 1 && glyph.size.width - glyph.screen.maxX > 1
        return crowded && !both ? max(glyph.size.width, 3 * glyph.screen.width) : glyph.size.width
    }

    /// The zoom of the open island: `MenuBarIslandView.hoverZoom`, or less when the room would not fit the display.
    func fitZoom(toDisplayWidth width: CGFloat) -> CGFloat { max(1, min(MenuBarIslandView.hoverZoom, (width - 2 * barHeight) / max(roomWidth, 1))) }
    private var cardsGeometry: CarouselCards { CarouselCards(count: windows.count, wide: windowsFrame.width, fit: cardsFit) }
    var cardsOther: CGFloat { cardsGeometry.other(front: windows.firstIndex(where: \.isActive)) }
    /// The card under a point `x` from the middle of the row.
    func card(atX x: CGFloat) -> Int? { cardsGeometry.card(atX: x, at: cardsAt, other: cardsOther) }

    /// The place of the window in front among the cards, in cards: the fingers' drag moves it among the open windows, and the cards of apps that are not
    /// open lie between. Nil when no window is in front.
    var cardsAt: CGFloat? {
        let open = windows.indices.filter { windows[$0].windowID != nil }
        guard let front = open.firstIndex(where: { windows[$0].isActive }) else { return nil }
        let place = min(max(CGFloat(front) - windowsDrag, 0), CGFloat(open.count - 1))
        let low = Int(place.rounded(.down)), high = min(low + 1, open.count - 1)
        return CGFloat(open[low]) + CGFloat(open[high] - open[low]) * (place - CGFloat(low))
    }

    /// The height of what stands under the picture: none while no zone is chosen.
    var windowsHeight: CGFloat { windowsZone == nil ? 0 : windowsFrame.height + titleGap + captionHeight }

    /// The open island: as wide as the picture and the room round it, as tall as the picture, the windows of a chosen zone under it, and the room round it.
    var openSize: CGSize { CGSize(width: cardsFit + 2 * barHeight, height: openHeight(windows: windowsHeight)) }

    /// The tallest the open island gets, with the largest zone chosen: the panel it grows in is as tall as that.
    var tallestOpenHeight: CGFloat {
        openHeight(windows: (glyph.cells.map(\.rect.height).max() ?? 0) * openZoom + titleGap + captionHeight)
    }

    private func openHeight(windows rowHeight: CGFloat) -> CGFloat { barHeight + glyph.size.height * openZoom + (rowHeight > 0 ? windowsGap + rowHeight + windowsGap : barHeight) }

    /// The focus went to another zone: it lights up as the old one goes out.
    func select(_ id: UUID?) {
        guard id != activeID else { return }
        previousID = activeID
        activeID = id
        withTransaction(Transaction(animation: nil)) { blend = 0 }
        DispatchQueue.main.async { [self] in withAnimation(.easeOut(duration: 0.15)) { blend = 1 } }
    }
}
