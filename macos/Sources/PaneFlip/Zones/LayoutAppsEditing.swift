import AppKit
import Foundation
import PaneFlipCore

/// What the rest of the app asks of the apps of a layout: their icons, which of them start with it, starting them, and the apps of its zones in their order (moved to another
/// zone, put in another place, taken out, all forgotten). A view that lists them is drawn again whenever they change.
protocol LayoutAppsEditing: AnyObject {
    /// The same for the windows of one scene: each scene remembers its own, so the apps of a layout are the scene's, not those of the scene in use.
    func editing(scene: UUID) -> LayoutAppsEditing
    /// The layout's apps in the island's order, one entry per app and zone. `zones` is the layout's zone identifiers.
    func entries(inZones zones: [UUID]) -> [LayoutAppEntry]
    /// The app's icon as the island draws it: a one-colour glyph that follows the text colour.
    func glyph(ofApp bundleID: String) -> NSImage
    /// The apps of the layout that are ticked to be started and still have a zone in it.
    func startApps(of layout: NamedLayout) -> [String]
    /// Starts those of the apps that are not running (they are placed as they open).
    func open(apps bundleIDs: [String])
    /// Puts the app in `zone` and opens it there (it is started, or asked to open a window).
    func launch(app bundleID: String, into zone: UUID)
    /// Puts the app in `zone`'s stack without opening it.
    func add(app bundleID: String, to zone: UUID)
    func move(app bundleID: String, from zone: UUID, to target: UUID, inZones zones: [UUID])
    /// -1 shows the app earlier in its zone's row, 1 later.
    func reorder(app bundleID: String, in zone: UUID, by offset: Int, inZones zones: [UUID])
    /// -1 shows the window earlier among the windows of its app, 1 later.
    func reorder(window slot: Int, by offset: Int, inZones zones: [UUID])
    /// Empties the zones of a layout: nothing is remembered of them.
    func clear(zones: [UUID])
    func remove(app bundleID: String, in zone: UUID, inZones zones: [UUID])
}
