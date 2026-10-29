import Foundation
import PaneFlipCore

/// The island as a place to choose a zone in: opened on the display that has the zone, without its row of windows, with a zone lit in a colour of its own.
protocol ZonePicking: AnyObject {
    /// Opens the island of the display with `zone` and lights the zone. False when no island has the zone.
    func startPicking(zone: UUID) -> Bool
    /// Lights another zone.
    func pick(_ zone: UUID)
    /// The zone that lies next to `zone` in the island's picture in a direction, if there is one.
    func zone(toward direction: ZoneDirection, from zone: UUID) -> UUID?
    /// Closes the island.
    func stopPicking()
}
