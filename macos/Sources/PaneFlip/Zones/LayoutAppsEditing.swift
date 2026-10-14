import Foundation

/// What the settings need to decide, per layout, which app opens in which zone and in what order the pill shows them.
/// `zones` is always the layout's zone identifiers.
protocol LayoutAppsEditing: AnyObject {
    /// Changes whenever the apps changed, so a view that reads it is redrawn.
    var revision: Int { get }
    /// The layout's apps in pill order.
    func entries(inZones zones: [UUID]) -> [LayoutAppEntry]
    /// Running apps that can be added.
    func runningApps() -> [(bundleID: String, name: String)]
    func addApp(bundleID: String, to zone: UUID)
    func move(slot: Int, to zone: UUID, inZones zones: [UUID])
    /// -1 shows the app earlier in its zone's pill, 1 later.
    func reorder(slot: Int, by offset: Int, inZones zones: [UUID])
    func remove(slot: Int)
}
