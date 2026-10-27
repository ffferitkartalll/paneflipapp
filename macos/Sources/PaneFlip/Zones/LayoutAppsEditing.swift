import AppKit
import Foundation
import PaneFlipCore

/// What the settings need to decide, per layout, which app opens in which zone and in what order the island shows
/// them (and, within an app, its windows). `zones` is always the layout's zone identifiers.
protocol LayoutAppsEditing: AnyObject {
    /// Changes whenever the apps changed, so a view that reads it is redrawn.
    var revision: Int { get }
    /// The layout's apps in the island's order, one entry per app and zone.
    func entries(inZones zones: [UUID]) -> [LayoutAppEntry]
    /// The app's icon as the island draws it: a one-colour glyph that follows the text colour.
    func glyph(ofApp bundleID: String) -> NSImage
    /// Running apps that can be added.
    func runningApps() -> [(bundleID: String, name: String)]
    /// The apps of the layout that are ticked to be started and still have a zone in it.
    func startApps(of layout: NamedLayout) -> [String]
    /// Starts those of the apps that are not running (they are placed as they open).
    func open(apps bundleIDs: [String])
    func addApp(bundleID: String, to zone: UUID)
    func move(app bundleID: String, from zone: UUID, to target: UUID, inZones zones: [UUID])
    /// -1 shows the app earlier in its zone's row, 1 later.
    func reorder(app bundleID: String, in zone: UUID, by offset: Int, inZones zones: [UUID])
    /// -1 shows the window earlier among the windows of its app, 1 later.
    func reorder(window slot: Int, by offset: Int, inZones zones: [UUID])
    func remove(app bundleID: String, in zone: UUID, inZones zones: [UUID])
}
