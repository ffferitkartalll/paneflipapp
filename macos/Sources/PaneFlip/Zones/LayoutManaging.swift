import Foundation
import PaneFlipCore

/// What the UI may do to layouts. The settings window and the editor depend on this, not on the service.
protocol LayoutManaging: AnyObject {
    @discardableResult func addLayout(for key: String, preset: LayoutPreset) -> NamedLayout
    func duplicate(key: String, id: UUID)
    func importLayout(for key: String, _ layout: NamedLayout)
    /// `animated`: the windows glide to their new places (a line between zones was moved by hand) instead of jumping.
    func updateLayout(key: String, id: UUID, strip: StripLayout, animated: Bool)
    /// Does nothing for the last layout of a display: it is never removed (see `resetLayout`).
    func removeLayout(key: String, id: UUID)
    /// The layout goes back to one zone with no space round or between zones and nothing beyond the edges; its windows go to that zone.
    func resetLayout(key: String, id: UUID)
    /// `remapping`: the windows of the layout that was in use are put in the zones of the new one that lie where theirs did (a scene change loads the windows of the
    /// scene instead).
    func activate(key: String, id: UUID, remapping: Bool)
    /// The key's desktop gets no layout, so no zones.
    func deactivate(key: String)
    /// Takes effect with the next `updateLayout`, which lays the zones out again.
    func setSpacing(key: String, id: UUID, gap: Double, edgeMargin: Double, minZoneSize: Double)
    func setZoneName(key: String, id: UUID, zone: UUID, to name: String)
    func setZoneAspects(key: String, id: UUID, _ aspects: [UUID: ZoneAspect])
    func setLauncherZones(key: String, id: UUID, _ zones: Set<UUID>)
    func rename(key: String, id: UUID, to name: String)
    /// The zone that receives the apps of a display that is unplugged; nil leaves it to the first zone.
    func setDefaultZone(key: String, id: UUID, to zone: UUID?)
}

extension LayoutManaging {
    func activate(key: String, id: UUID) { activate(key: key, id: id, remapping: true) }
    func updateLayout(key: String, id: UUID, strip: StripLayout) { updateLayout(key: key, id: id, strip: strip, animated: false) }
}
