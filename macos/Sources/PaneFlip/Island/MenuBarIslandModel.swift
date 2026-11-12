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
    /// What was just done to a zone, told in one line under the bar with a button to undo it, the island otherwise at rest (see `MenuBarIsland.showNotice`).
    var notice: AttributedString?
    /// How much of the time of the notice is left (1 to 0): the ring round its close button.
    var noticeLeft: CGFloat = 1
    /// The notice can be closed (it has a close button, and the ring runs round that); else the ring runs round the Undo button.
    var noticeCloses = true
    /// The notice is the one that tells the editing of the zones' edges is on: it stays until that is over, and its button (Done) ends that.
    var noticeEditing = false
    /// Under the editing notice a second line says that a zone edge was moved, with a button that undoes it.
    var noticeUndo = false
    /// The width of the display, at most the width of the island.
    var displayWidth: CGFloat = 0
    /// How far the fingers (or the wheel's turn) have led the windows from the one in front, in windows: positive brings the ones before it in.
    var windowsDrag: CGFloat = 0
    /// The card the mouse is over (`IslandWindow.id`) while the island is open under the pointer: it shows its buttons. Nil when the mouse is on none.
    var hoveredCard: String?
    /// The button the pointer is over: it is drawn lighter.
    var hoveredButton: IslandButton?
    /// The zone of the picture, and the card of the row (`IslandWindow.id`), the pointer is over: a click there does something, so they are drawn lighter.
    private(set) var hoveredZone: UUID?
    /// The zone the pointer left, and how far the change has come (0 to 1): the lighter fill fades over, as the lit zone of the focus does.
    private(set) var previousHoveredZone: UUID?
    var zoneHoverBlend: CGFloat = 1
    var hoveredWindow: String?
    /// The card the mouse carries (`IslandWindow.id`), and where its middle is, from the middle of the row.
    var carriedCard: String?
    /// The card is held up: it is put down while it goes to its place.
    var liftedCard: String?
    var carriedX: CGFloat = 0
    var barHeight: CGFloat = 24
    /// 0 on a display without a notch.
    var notchWidth: CGFloat = 0
    /// The island is not used as one: at rest it is out of sight (it shows when it is open or holds a notice).
    var restsHidden = false
    var isHidden: Bool { restsHidden && !expanded && notice == nil }
    /// Drawn as a popover under the menu bar, on the system's ground, not as the island at the notch (set a moment after `restsHidden`, once the island has faded out).
    var popover = false
    /// The ground of the open island: black, as the notch is, or the system's own.
    var ground: Color { popover ? Color(nsColor: .windowBackgroundColor) : .black }
    /// How far the panel stands below the top of the display: right under the menu bar (the room for the arrow is the top of the panel).
    var drop: CGFloat { popover ? barHeight : 0 }
    /// The arrow of the popover that points at the menu bar icon, as a popover has one.
    static let arrowSize = CGSize(width: 18, height: 10)
    /// Where the arrow stands, from the middle of the panel; nil: the icon is not on this display.
    var arrowX: CGFloat?
    /// The room above the island for the arrow.
    var arrowBand: CGFloat { popover && arrowX != nil ? Self.arrowSize.height : 0 }
    /// How large the popover is: it grows from the icon and shrinks back into it, so closed it is a speck there.
    var popoverScale: CGFloat { popover && !expanded && notice == nil ? 0.05 : 1 }
    /// The top of the island's shape in a panel of this frame (screen coordinates).
    func shapeTop(of panel: CGRect) -> CGFloat { panel.maxY - arrowBand }
    /// The colour of the drawing on that ground.
    func ink(for scheme: ColorScheme) -> IslandInk { IslandInk(light: popover && scheme == .light) }
    /// Device pixels per point of the display: what the drawing is aligned to.
    var scale: CGFloat = 2

    /// The pointer is over another zone (nil: none).
    func hover(zone id: UUID?) {
        guard id != hoveredZone else { return }
        previousHoveredZone = hoveredZone
        hoveredZone = id
        withTransaction(Transaction(animation: nil)) { zoneHoverBlend = 0 }
        DispatchQueue.main.async { [self] in withAnimation(.easeOut(duration: 0.12)) { zoneHoverBlend = 1 } }
    }

    /// The zone a window is being sent to changes (nil: none): it lights up as the old one goes out.
    /// The island is the one opened to choose the zone for a window: it stays so until the pointer opens it again, also while it closes (its shape must not change then).
    private(set) var choosing = false

    /// The pointer opened the island.
    func openedByPointer() { choosing = false }

    /// A window is being dragged onto the island, or sent with the keys: it shows no buttons.
    func startChoosing() { choosing = true }

    func pick(_ id: UUID?) {
        if id != nil { choosing = true }
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
