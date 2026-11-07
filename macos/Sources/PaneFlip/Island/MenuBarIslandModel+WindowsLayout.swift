import AppKit
import Foundation
import Observation
import SwiftUI
import PaneFlipCore

extension MenuBarIslandModel {
    /// The frame of the chosen zone's windows under the picture (a card, see `windowsFrame`), and the line
    /// with the title of the window in front under it. The gap between the picture and the frame.
    var windowsGap: CGFloat { barHeight / 2 }
    /// The room at the sides and at the foot of the open island (the one between the title of a card and the foot), and the same room above the buttons of the top row, between them, and between that row and the picture.
    var sideRoom: CGFloat { windowsGap }
    /// The row of buttons at the top of the open island: as tall as its buttons and the room above and below them.
    var topHeight: CGFloat { hasButtonRow ? Self.cornerHeight + 2 * sideRoom : sideRoom }
    /// The island that is opened to choose the zone a window is sent to (with the shortcut, or by dragging the window onto it) shows no buttons. Where the display has no
    /// notch it has no row for them either, only the room above the picture; with a notch the row stays, empty.
    var showsButtons: Bool { !choosing }
    var hasButtonRow: Bool { !choosing || notchWidth > 0 }
    /// Where the picture of the zones ends when the island is at rest, from the top.
    var restBottom: CGFloat { barHeight - MenuBarIslandView.margin }
    /// The title under a card, and the line under that.
    var captionHeight: CGFloat { 16 }
    private var titleGap: CGFloat { windowsGap }   // the title stands as far from the frame as from the island's lower edge

    /// The size of a card: as tall as the screen the island is on is drawn in the open island's picture (when the windows are shown alone too), 16:9, whatever the zone is.
    var windowsFrame: CGSize {
        guard glyph.cells.contains(where: { $0.id == windowsZone }) else { return .zero }
        return Self.cardSize(screenHeight: glyph.screen.height * openZoom)
    }

    private static func cardSize(screenHeight: CGFloat) -> CGSize { CGSize(width: screenHeight * 16 / 9, height: screenHeight) }

    /// The room the row of cards has: at least as wide as the picture, and wide enough for every card when the display has room; the cards that still do not fit
    /// are cut by the edges of the island. With the windows shown alone, no wider than the cards.
    var cardsFit: CGFloat {
        peeking ? min(cardsNeeded, displayWidth - 2 * sideRoom) : max(glyph.size.width * openZoom, min(cardsNeeded, displayWidth - 2 * sideRoom))
    }

    /// The width that shows every card of the row: the island grows to this much, never past the display. Nothing without a row.
    private var cardsNeeded: CGFloat { windowsFrame.width * CGFloat(windows.count) }

    /// The room the cards are shown in: the island itself, the picture and the room beside it.
    var windowsSpan: CGFloat { cardsFit + 2 * sideRoom }

    /// The zoom of the open island: `MenuBarIslandView.hoverZoom`, or less when the picture would not fit the display.
    func fitZoom(toDisplayWidth width: CGFloat) -> CGFloat { max(1, min(MenuBarIslandView.hoverZoom, (width - 2 * sideRoom) / max(glyph.size.width, 1))) }
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
    var windowsHeight: CGFloat { windowsZone == nil ? pickingNoteHeight : windowsFrame.height + (windows.isEmpty ? 0 : titleGap + captionHeight) }   // no windows: no title under the card

    /// The note under the picture that says a zone is being chosen for a window, in the type of the date and the time of the menu bar; it goes on to
    /// another line when it does not fit the width of the room, and the island is as tall as its lines.
    var pickingNote: String { String(localized: "Window placement shortcut is active") }
    static var pickingNoteFont: NSFont { NSFont.menuBarFont(ofSize: 0) }
    var pickingNoteHeight: CGFloat {
        guard pickedID != nil else { return 0 }
        let box = CGSize(width: max(cardsFit, 1), height: .greatestFiniteMagnitude)
        return ceil(NSString(string: pickingNote).boundingRect(with: box, options: .usesLineFragmentOrigin, attributes: [.font: Self.pickingNoteFont]).height)
    }

    /// The buttons of the open island, in the row above the picture: a symbol and the words, two at its left edge and two at its right one.
    static let cornerHeight: CGFloat = 28, cornerPadding: CGFloat = 14, cornerSymbol: CGFloat = 17, cornerSymbolGap: CGFloat = 6
    var cornerGap: CGFloat { sideRoom }
    var cornerButtonsOpacity: CGFloat { expanded && showsButtons ? contentOpacity : 0 }
    func cornerButtonWidth(_ action: IslandCornerAction) -> CGFloat {
        ceil(NSString(string: action.title).size(withAttributes: [.font: Self.noticeFont]).width) + Self.cornerSymbol + Self.cornerSymbolGap + 2 * Self.cornerPadding
    }
    /// The width of the buttons on one side of the row, with the gaps between them.
    private func cornerGroupWidth(onLeft: Bool) -> CGFloat {
        let group = IslandCornerAction.allCases.filter { $0.isOnLeft == onLeft }
        return group.reduce(0) { $0 + cornerButtonWidth($1) } + CGFloat(group.count - 1) * cornerGap
    }
    /// The width the row of buttons needs, with the room at its sides. With a notch the notch lies between the two groups, the room from it to each as large as that round
    /// the island, and the groups are as wide on both sides of the middle (the notch is in the middle of the island).
    var cornerRowWidth: CGFloat {
        let left = cornerGroupWidth(onLeft: true), right = cornerGroupWidth(onLeft: false)
        let inside = notchWidth > 0 ? 2 * max(left, right) + notchWidth + 2 * sideRoom : left + right + 2 * cornerGap
        return inside + 2 * sideRoom
    }
    /// The middle of a button, from the middle of the island's top edge: x to the right, y down. The left ones begin at the island's left room, the right ones
    /// end at its right room.
    func cornerButtonCentre(_ action: IslandCornerAction) -> CGPoint {
        let same = IslandCornerAction.allCases.filter { $0.isOnLeft == action.isOnLeft }
        let at = same.firstIndex(of: action) ?? 0
        let before = same[..<at].reduce(CGFloat(0)) { $0 + cornerButtonWidth($1) + cornerGap }
        let after = same[(at + 1)...].reduce(CGFloat(0)) { $0 + cornerButtonWidth($1) + cornerGap }
        let half = openSize.width / 2 - sideRoom, width = cornerButtonWidth(action)
        return CGPoint(x: action.isOnLeft ? -half + before + width / 2 : half - after - width / 2, y: topHeight / 2)
    }

    /// The line of the notice: its text, the button that undoes it and the one that closes it (a square with only an icon).
    static var noticeFont: NSFont { NSFont.menuBarFont(ofSize: 0) }
    static let noticeGap: CGFloat = 8, noticeButtonPadding = cornerPadding, noticeButtonHeight = cornerHeight, noticeRadius = cornerHeight / 2
    var noticeButtonTitle: String { noticeEditing ? String(localized: "Done") : String(localized: "Undo") }
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
        let line = AttributedString(String(text[..<at.lowerBound]))
        var bold = AttributedString(name)
        bold.inlinePresentationIntent = .stronglyEmphasized
        return line + bold + AttributedString(String(text[at.upperBound...]))
    }
    /// The room the close button takes, with the gap before it.
    var noticeCloseWidth: CGFloat { noticeCloses ? Self.noticeButtonHeight + Self.noticeGap : 0 }
    /// The second line, while the editing notice has one: the zone edge that was moved and the button that undoes it.
    var hasEditUndo: Bool { notice != nil && noticeEditing && noticeUndo }
    static var editUndoText: String { String(localized: "The zone edge was moved.") }
    static var editUndoButtonWidth: CGFloat { ceil(NSString(string: String(localized: "Undo")).size(withAttributes: [.font: noticeFont]).width) + 2 * noticeButtonPadding }
    var editUndoTextWidth: CGFloat { ceil(NSString(string: Self.editUndoText).size(withAttributes: [.font: Self.noticeFont]).width) }
    var noticeEditUndoWidth: CGFloat { hasEditUndo ? editUndoTextWidth + Self.noticeGap + Self.editUndoButtonWidth : 0 }
    /// Where the second line begins, from the top of the island.
    var noticeEditUndoTop: CGFloat { noticeTop + Self.noticeButtonHeight + windowsGap }
    /// The height of the lines of the notice together.
    var noticeBlockHeight: CGFloat { hasEditUndo ? 2 * Self.noticeButtonHeight + windowsGap : Self.noticeButtonHeight }
    var noticeRowWidth: CGFloat { noticeTextWidth + Self.noticeGap + noticeButtonWidth + noticeCloseWidth }

    /// The open island: as wide as the picture and the room round it, as tall as the picture, the windows of a chosen zone under it, and the room round it.
    var openSize: CGSize {
        guard notice != nil else { return plainOpenSize }
        // A notice: with the pointer away the picture stays as it is at rest and the island holds one line under it, no wider than the closed island unless the line needs
        // more; with the pointer on the island it is the open island with the line at its foot.
        let line = max(noticeRowWidth, noticeEditUndoWidth) + 2 * windowsGap, height = noticeTop + noticeBlockHeight + windowsGap
        // The windows of a zone shown alone (stepping through them) lie under the line too.
        guard expanded || peeking else { return CGSize(width: max(line, glyph.size.width + notchWidth + 2 * MenuBarIslandView.margin), height: height) }
        return CGSize(width: max(plainOpenSize.width, line), height: height + (windowsHeight > 0 ? windowsHeight + windowsGap : 0))
    }

    /// Where the line of the notice begins, from the top of the island: under the bar, or, with the island open, under the picture of the zones (above the row of cards).
    var noticeTop: CGFloat { expanded ? topHeight + glyph.size.height * openZoom + windowsGap : restBottom + windowsGap }

    /// Where the row of cards begins: under the picture, and under the line of a notice if there is one (with the windows shown alone, under the bar).
    var windowsTop: CGFloat { noticeTop + (notice != nil ? noticeBlockHeight + windowsGap : 0) }

    private var plainOpenSize: CGSize {
        let width = windowsSpan
        return CGSize(width: peeking ? max(width, glyph.size.width + notchWidth + 2 * MenuBarIslandView.margin) : max(width, cornerRowWidth),
                      height: openHeight(picture: peeking ? 0 : glyph.size.height * openZoom, windows: windowsHeight))
    }

    /// The tallest the open island gets, with the largest zone chosen: the panel it grows in is as tall as that.
    var tallestOpenHeight: CGFloat {
        openHeight(picture: glyph.size.height * openZoom, windows: Self.cardSize(screenHeight: glyph.screen.height * openZoom).height + titleGap + captionHeight)
            + 2 * Self.noticeButtonHeight + 2 * windowsGap   // the lines of a notice at the foot
    }

    private func openHeight(picture: CGFloat, windows rowHeight: CGFloat) -> CGFloat { (peeking ? restBottom : topHeight) + picture + (rowHeight > 0 ? windowsGap + rowHeight + windowsGap : sideRoom) }
}
