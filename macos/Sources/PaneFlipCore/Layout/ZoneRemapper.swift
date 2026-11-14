import CoreGraphics
import Foundation

/// Decides where the apps of vanished zones go when a layout is edited.
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

    /// The zones of the screens beyond the edges that the new layout no longer has map to `home` (a screen beyond the edge was removed in the layout editor).
    public static func beyondEdges(old: StripLayout, new: StripLayout, home: UUID) -> [UUID: UUID] {
        let alive = Set(new.zoneIDs), screen = Set(old.root.leafIDs)
        return Dictionary(uniqueKeysWithValues: old.zoneIDs.filter { !screen.contains($0) && !alive.contains($0) }.map { ($0, home) })
    }
}
