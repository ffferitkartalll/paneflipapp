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
    /// A dragged window is over a zone of the island: that zone is lit whole, also the part of it beyond the edges of the screen.
    var dropping = false
    var cellTexts: [UUID: String] = [:]
    /// The zone chosen in the picture by a click: its windows stand under the picture, in a frame while it is set.
    var windowsZone: UUID?
    /// The windows of that zone (they stay while the row closes, so that it fades instead of going at once).
    var windows: [IslandWindow] = []
    /// How far the fingers (or the wheel's turn) have led the windows from the one in front, in windows: positive brings the ones before it in.
    var windowsDrag: CGFloat = 0
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
    private var titleHeight: CGFloat { 16 }
    private var titleGap: CGFloat { 4 }

    var windowsFrame: CGSize {
        guard let cell = glyph.cells.first(where: { $0.id == windowsZone }) else { return .zero }
        return CGSize(width: min(cell.rect.width * openZoom, glyph.size.width * openZoom), height: cell.rect.height * openZoom)
    }

    /// The height of what stands under the picture: none while no zone is chosen.
    var windowsHeight: CGFloat { windowsZone == nil ? 0 : windowsFrame.height + titleGap + titleHeight }

    /// The open island: as wide as the picture and the room round it, as tall as the picture, the windows of a chosen zone under it, and the room round it.
    var openSize: CGSize { CGSize(width: glyph.size.width * openZoom + 2 * barHeight, height: openHeight(windows: windowsHeight)) }

    /// The tallest the open island gets, with the largest zone chosen: the panel it grows in is as tall as that.
    var tallestOpenHeight: CGFloat {
        openHeight(windows: (glyph.cells.map(\.rect.height).max() ?? 0) * openZoom + titleGap + titleHeight)
    }

    private func openHeight(windows rowHeight: CGFloat) -> CGFloat { barHeight + glyph.size.height * openZoom + (rowHeight > 0 ? windowsGap + rowHeight : 0) + barHeight }

    /// The focus went to another zone: it lights up as the old one goes out.
    func select(_ id: UUID?) {
        guard id != activeID else { return }
        previousID = activeID
        activeID = id
        withTransaction(Transaction(animation: nil)) { blend = 0 }
        DispatchQueue.main.async { [self] in withAnimation(.easeOut(duration: 0.15)) { blend = 1 } }
    }
}
