import AppKit
import PaneFlipCore
import SwiftUI

extension MenuBarIsland {
    /// One display's island.
    final class Entry {
        let model = MenuBarIslandModel()
        let panel: NSPanel
        /// A small panel exactly over the island that takes the mouse (the picture's own panel lets it through): nothing behind the island sees the pointer.
        let shield: NSPanel
        /// The shield shrinks when the island has shrunk, not before.
        var shrinking: DispatchWorkItem?
        var zoneNames: [UUID: String] = [:]
        var zones: Set<UUID> = []
        /// The display, in Cocoa coordinates.
        var display: CGRect = .zero
        /// How each zone is numbered: 1, 2 on the screen; -1 beyond the left edge; +1 beyond the right one.
        var numbers: [UUID: String] = [:]
        var hovered = false
        /// A drop just ended on the island: it stays closed until the pointer has left it.
        var cooling = false
        /// The zone a dragged window would be dropped on: it is lit, as a zone with the focus is.
        var dropZone: UUID?
        /// The zone of the picture a dragged window has waited on, and since when: after a second its row of cards opens.
        var dwell: (zone: UUID, since: Date)?
        /// Where the panel stands when the island is in sight.
        var rest: CGRect = .zero
        /// The layout offset the picture of the zones was built at: the frame is drawn at the offsets of the scroll minus this one.
        var builtOffset: CGFloat = 0
        /// Counts the glides told to the island: one that is overtaken does not start.
        var glides = 0
        #if DEBUG
        var mockNotch: NSPanel?
        #endif
        /// The last offset the fingers told, and whether it is being drawn already: told as often as events come, drawn once per turn of the run loop.
        var following: CGFloat?
        var dragging: CGFloat?
        /// Ends the showing of the windows alone (`peekWindows`).
        var peekEnd: DispatchWorkItem?
        /// Ends the notice (`showNotice`).
        var noticeEnd: DispatchWorkItem?

        init(panel: NSPanel, shield: NSPanel) {
            self.panel = panel
            self.shield = shield
        }
    }
}
