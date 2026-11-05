import Foundation
import PaneFlipCore

/// What the UI may do to layouts. The settings window and the editor depend on this, not on the service.
protocol LayoutManaging: AnyObject {
    @discardableResult func addLayout(for key: String, preset: LayoutPreset) -> NamedLayout
    func duplicate(key: String, id: UUID)
    func importLayout(for key: String, _ layout: NamedLayout)
    /// `animated`: the windows glide to their new places (a line between zones was moved by hand) instead of jumping.
    func updateLayout(key: String, id: UUID, strip: StripLayout, animated: Bool)
    func removeLayout(key: String, id: UUID)
    func activate(key: String, id: UUID)
    /// The key's desktop gets no layout, so no zones.
    func deactivate(key: String)
    /// The gap between the zones of the layout; nil takes the one of the settings.
    func setStartApp(key: String, id: UUID, bundleID: String, chosen: Bool)
    /// Takes effect with the next `updateLayout`, which lays the zones out again.
    func setSpacing(key: String, id: UUID, gap: Double, edgeMargin: Double, minZoneSize: Double)
    func setZoneName(key: String, id: UUID, zone: UUID, to name: String)
    func rename(key: String, id: UUID, to name: String)
    /// The zone that receives the apps of a display that is unplugged; nil leaves it to the first zone.
    func setDefaultZone(key: String, id: UUID, to zone: UUID?)
}

extension LayoutManaging {
    func updateLayout(key: String, id: UUID, strip: StripLayout) { updateLayout(key: key, id: id, strip: strip, animated: false) }
}
