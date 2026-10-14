import Foundation

/// What the settings need to decide, per layout, which app opens in which zone and in what order the pill shows
/// them (and, within an app, its windows). `zones` is always the layout's zone identifiers.
protocol LayoutAppsEditing: AnyObject {
    /// Changes whenever the apps changed, so a view that reads it is redrawn.
    var revision: Int { get }
    /// The layout's apps in pill order, one entry per app and zone.
    func entries(inZones zones: [UUID]) -> [LayoutAppEntry]
    /// Running apps that can be added.
    func runningApps() -> [(bundleID: String, name: String)]
    func addApp(bundleID: String, to zone: UUID)
    func move(app bundleID: String, from zone: UUID, to target: UUID, inZones zones: [UUID])
    /// -1 shows the app earlier in its zone's pill, 1 later.
    func reorder(app bundleID: String, in zone: UUID, by offset: Int, inZones zones: [UUID])
    /// -1 shows the window earlier among the windows of its app, 1 later.
    func reorder(window slot: Int, by offset: Int, inZones zones: [UUID])
    func remove(app bundleID: String, in zone: UUID, inZones zones: [UUID])
}
