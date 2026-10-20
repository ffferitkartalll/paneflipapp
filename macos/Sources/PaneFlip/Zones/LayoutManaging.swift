import Foundation
import PaneFlipCore

/// What the UI may do to layouts. The settings window and the editor depend on this, not on the service.
protocol LayoutManaging: AnyObject {
    @discardableResult func addLayout(for key: String, preset: LayoutPreset) -> NamedLayout
    func duplicate(key: String, id: UUID)
    func updateLayout(key: String, id: UUID, strip: StripLayout)
    func removeLayout(key: String, id: UUID)
    func activate(key: String, id: UUID)
    /// The key's desktop gets no layout, so no zones.
    func deactivate(key: String)
    /// The gap between the zones of the layout; nil takes the one of the settings.
    func setGap(key: String, id: UUID, to gap: Double?)
    func rename(key: String, id: UUID, to name: String)
    /// The zone that receives the apps of a display that is unplugged; nil leaves it to the first zone.
    func setDefaultZone(key: String, id: UUID, to zone: UUID?)
}
