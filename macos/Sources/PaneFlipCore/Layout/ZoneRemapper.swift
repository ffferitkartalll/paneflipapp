import CoreGraphics
import Foundation

/// Decides where the apps of vanished zones go when a layout changes.
public enum ZoneRemapper {
    /// Zones that no longer exist map to the new zone that covers their centre (merge, reset).
    public static func byCoverage(old: LayoutNode, new: LayoutNode, in area: CGRect) -> [UUID: UUID] {
        let alive = Set(new.leafIDs)
        let newZones = new.zones(in: area)
        var map: [UUID: UUID] = [:]
        for zone in old.zones(in: area) where !alive.contains(zone.id) {
            let centre = CGPoint(x: zone.rect.midX, y: zone.rect.midY)
            if let target = newZones.first(where: { $0.rect.contains(centre) }) { map[zone.id] = target.id }
        }
        return map
    }

    /// Zones map to the new layout's zones by position; surplus zones collapse onto the last one (switching layouts).
    public static func byOrder(old: LayoutNode, new: LayoutNode) -> [UUID: UUID] {
        let newIDs = new.leafIDs
        guard !newIDs.isEmpty else { return [:] }
        var map: [UUID: UUID] = [:]
        for (i, id) in old.leafIDs.enumerated() { map[id] = newIDs[min(i, newIDs.count - 1)] }
        return map
    }
}
