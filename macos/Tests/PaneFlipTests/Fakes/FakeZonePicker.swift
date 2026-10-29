import Foundation
import PaneFlipCore

/// An island to choose a zone in: remembers what it was asked, and goes from zone to zone along a list.
final class FakeZonePicker: ZonePicking {
    var isOpen = false
    var lit: UUID?
    /// The zones left to right, as the picture shows them.
    var row: [UUID] = []

    func startPicking(zone: UUID) -> Bool {
        guard row.contains(zone) else { return false }
        isOpen = true
        lit = zone
        return true
    }

    func pick(_ zone: UUID) { lit = zone }

    func zone(toward direction: ZoneDirection, from zone: UUID) -> UUID? {
        guard let i = row.firstIndex(of: zone) else { return nil }
        switch direction {
        case .left: return i > 0 ? row[i - 1] : nil
        case .right: return i + 1 < row.count ? row[i + 1] : nil
        default: return nil
        }
    }

    func stopPicking() {
        isOpen = false
        lit = nil
    }
}
