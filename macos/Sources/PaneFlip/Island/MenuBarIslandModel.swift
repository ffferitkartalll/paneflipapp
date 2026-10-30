import AppKit
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
    /// The zone a window is being sent to: lit in a colour of its own.
    private(set) var pickedID: UUID?
    /// The zone that was lit before, and how far the change to the new one has come (0 to 1): the colour fades over, as the lit zone of the focus does.
    private(set) var previousPickedID: UUID?
    var pickBlend: CGFloat = 1
    /// The zone chosen in the picture by a click: its windows stand under the picture, in a frame while it is set.
    var windowsZone: UUID?
    /// The windows of that zone (they stay while the row closes, so that it fades instead of going at once).
    var windows: [IslandWindow] = []
    /// The island has grown only to show the windows of `windowsZone`, with no picture of the zones, because a window of the zone was stepped to (see `MenuBarIsland.peekWindows`).
    var peeking = false
    /// What was just done to a zone, told in one line under the bar with a button to undo it, the island otherwise at rest (see `MenuBarIsland.showNotice`).
    var notice: AttributedString?
    /// How much of the time of the notice is left (1 to 0): the ring round its close button.
    var noticeLeft: CGFloat = 1
    /// The notice can be closed (it has a close button, and the ring runs round that); else the ring runs round the Undo button.
    var noticeCloses = true
    /// The width of the display, at most the width of the island.
    var displayWidth: CGFloat = 0
    /// How far the fingers (or the wheel's turn) have led the windows from the one in front, in windows: positive brings the ones before it in.
    var windowsDrag: CGFloat = 0
    /// The card the mouse carries (`IslandWindow.id`), and where its middle is, from the middle of the row.
    var carriedCard: String?
    /// The card is held up: it is put down while it goes to its place.
    var liftedCard: String?
    var carriedX: CGFloat = 0
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
        return CGSize(width: min(cell.rect.width * windowsZoom, glyph.size.width * windowsZoom), height: cell.rect.height * windowsZoom)
    }

    /// The room the row of cards has: at least as wide as the picture, and wide enough for every card when the display has room; the cards that still do not fit
    /// fade out toward the edges of the island. With the windows shown alone, no wider than the cards.
    var cardsFit: CGFloat {
        peeking ? min(cardsNeeded, displayWidth - 2 * barHeight) : max(glyph.size.width * openZoom, min(cardsNeeded, displayWidth - 2 * barHeight))
    }

    /// The width that shows every card of the row: the island grows to this much, never past the display. Nothing without a row.
    private var cardsNeeded: CGFloat { windowsFrame.width * CGFloat(windows.count) }

    /// The room the cards are shown in: the island itself, the picture and the room beside it.
    var windowsSpan: CGFloat { cardsFit + 2 * barHeight }

    /// The zoom the windows shown alone are drawn at: the zoom of an open island with a picture of the screen alone.
    var peekZoom: CGFloat { max(1, min(MenuBarIslandView.hoverZoom, (displayWidth - 2 * barHeight) / max(glyph.screen.width, 1))) }

    /// The zoom the frame of the windows is drawn at.
    private var windowsZoom: CGFloat { peeking ? peekZoom : openZoom }

    /// The zoom of the open island: `MenuBarIslandView.hoverZoom`, or less when the picture would not fit the display.
    func fitZoom(toDisplayWidth width: CGFloat) -> CGFloat { max(1, min(MenuBarIslandView.hoverZoom, (width - 2 * barHeight) / max(glyph.size.width, 1))) }
    private var cardsGeometry: CarouselCards { CarouselCards(count: windows.count, wide: windowsFrame.width) }
    var cardsOther: CGFloat { cardsGeometry.other }
    /// The middle of a card from the middle of the row, where it lies.
    func cardCentre(of card: Int) -> CGFloat { cardsGeometry.centres(at: nil, other: cardsOther)[card] + rowShift }
    /// How far the frame of the window in front is from the middle of the row: it goes along the row as another window comes to the front (or as the fingers
    /// lead it), and with the card when the mouse carries that.
    var frameShift: CGFloat {
        if carried != nil, carried == windows.firstIndex(where: \.isActive) { return carriedX }
        return activeCentre + rowShift
    }

    /// The middle of the card in front from the middle of the row (0 when none is in front).
    private var activeCentre: CGFloat { cardsAt.map { ($0 - CGFloat(windows.count - 1) / 2) * windowsFrame.width } ?? 0 }

    /// How far the row is moved from the middle: when it is wider than the room it has (the display is narrower than the cards need), it is moved so that the card
    /// in front is in view, as far as the ends of the row allow.
    var rowShift: CGFloat {
        let extra = windowsFrame.width * CGFloat(windows.count) - cardsFit
        guard extra > 0 else { return 0 }
        return min(max(-activeCentre, -extra / 2), extra / 2)
    }
    /// The card the mouse carries.
    var carried: Int? { carriedCard.flatMap { id in windows.firstIndex { $0.id == id } } }
    /// The card under a point `x` from the middle of the row.
    func card(atX x: CGFloat) -> Int? { cardsGeometry.card(atX: x - rowShift, at: nil, other: cardsOther) }

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
    var windowsHeight: CGFloat { windowsZone == nil ? pickingNoteHeight : windowsFrame.height + titleGap + captionHeight }

    /// The note under the picture that says a zone is being chosen for a window, in the type of the date and the time of the menu bar; it goes on to
    /// another line when it does not fit the width of the room, and the island is as tall as its lines.
    var pickingNote: String { String(localized: "Window placement shortcut is active") }
    static var pickingNoteFont: NSFont { NSFont.menuBarFont(ofSize: 0) }
    var pickingNoteHeight: CGFloat {
        guard pickedID != nil else { return 0 }
        let box = CGSize(width: max(cardsFit, 1), height: .greatestFiniteMagnitude)
        return ceil(NSString(string: pickingNote).boundingRect(with: box, options: .usesLineFragmentOrigin, attributes: [.font: Self.pickingNoteFont]).height)
    }

    /// The line of the notice: its text, the button that undoes it and the one that closes it (a square with only an icon).
    static var noticeFont: NSFont { NSFont.menuBarFont(ofSize: 0) }
    static let noticeGap: CGFloat = 8, noticeButtonPadding: CGFloat = 10, noticeButtonHeight: CGFloat = 22, noticeRadius: CGFloat = 10
    var noticeButtonTitle: String { String(localized: "Undo") }
    var noticeButtonWidth: CGFloat { ceil(NSString(string: noticeButtonTitle).size(withAttributes: [.font: Self.noticeFont]).width) + 2 * Self.noticeButtonPadding }
    /// The room the text has at most: the display less the side room and the two buttons.
    private var noticeTextRoom: CGFloat { max(displayWidth - 2 * windowsGap - Self.noticeGap - noticeButtonWidth - noticeCloseWidth, 1) }
    var noticeTextWidth: CGFloat {
        guard let notice else { return 0 }
        // The name is in bold: each run is measured in its own type.
        let bold = NSFontManager.shared.convert(Self.noticeFont, toHaveTrait: .boldFontMask)
        let width = notice.runs.reduce(CGFloat(0)) { sum, run in
            let font = run.inlinePresentationIntent == .stronglyEmphasized ? bold : Self.noticeFont
            return sum + NSString(string: String(notice[run.range].characters)).size(withAttributes: [.font: font]).width
        }
        return min(ceil(width), noticeTextRoom)
    }
    /// The line of a notice: `format` with the name of the window in bold and the zone's number.
    static func notice(_ format: String, name: String, number: String) -> AttributedString {
        let mark = "\u{1}", text = String(format: format, mark, number)
        guard let at = text.range(of: mark) else { return AttributedString(text) }
        var line = AttributedString(String(text[..<at.lowerBound]))
        var bold = AttributedString(name)
        bold.inlinePresentationIntent = .stronglyEmphasized
        return line + bold + AttributedString(String(text[at.upperBound...]))
    }
    /// The room the close button takes, with the gap before it.
    var noticeCloseWidth: CGFloat { noticeCloses ? Self.noticeButtonHeight + Self.noticeGap : 0 }
    var noticeRowWidth: CGFloat { noticeTextWidth + Self.noticeGap + noticeButtonWidth + noticeCloseWidth }

    /// The open island: as wide as the picture and the room round it, as tall as the picture, the windows of a chosen zone under it, and the room round it.
    var openSize: CGSize {
        // A notice: the picture stays as it is at rest, and the island holds one line under it; it is no wider than the closed island unless the line needs more.
        if notice != nil {
            return CGSize(width: max(noticeRowWidth + 2 * windowsGap, glyph.size.width + notchWidth + 2 * MenuBarIslandView.margin),
                          height: openHeight(picture: 0, windows: Self.noticeButtonHeight))
        }
        let width = windowsSpan
        return CGSize(width: peeking ? max(width, glyph.size.width + notchWidth + 2 * MenuBarIslandView.margin) : width,
                      height: openHeight(picture: peeking ? 0 : glyph.size.height * openZoom, windows: windowsHeight))
    }

    /// The tallest the open island gets, with the largest zone chosen: the panel it grows in is as tall as that.
    var tallestOpenHeight: CGFloat {
        openHeight(picture: glyph.size.height * openZoom, windows: (glyph.cells.map(\.rect.height).max() ?? 0) * max(openZoom, peekZoom) + titleGap + captionHeight)
    }

    private func openHeight(picture: CGFloat, windows rowHeight: CGFloat) -> CGFloat { barHeight + picture + (rowHeight > 0 ? windowsGap + rowHeight + windowsGap : barHeight) }

    /// The zone a window is being sent to changes (nil: none): it lights up as the old one goes out.
    func pick(_ id: UUID?) {
        guard id != pickedID else { return }
        previousPickedID = pickedID
        pickedID = id
        withTransaction(Transaction(animation: nil)) { pickBlend = 0 }
        DispatchQueue.main.async { [self] in withAnimation(.easeOut(duration: 0.15)) { pickBlend = 1 } }
    }

    /// The choice is over: nothing is lit, at once (the island is closing).
    func endPick() {
        pickedID = nil
        previousPickedID = nil
        pickBlend = 1
    }

    /// The focus went to another zone: it lights up as the old one goes out.
    func select(_ id: UUID?) {
        guard id != activeID else { return }
        previousID = activeID
        activeID = id
        withTransaction(Transaction(animation: nil)) { blend = 0 }
        DispatchQueue.main.async { [self] in withAnimation(.easeOut(duration: 0.15)) { blend = 1 } }
    }
}
