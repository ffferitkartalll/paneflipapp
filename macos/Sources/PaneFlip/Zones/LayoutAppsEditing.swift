import AppKit
import Foundation
import PaneFlipCore

/// What the rest of the app asks of the apps of a layout: their icons, which of them start with it, starting them and taking one out of a zone.
protocol LayoutAppsEditing: AnyObject {
    /// The app's icon as the island draws it: a one-colour glyph that follows the text colour.
    func glyph(ofApp bundleID: String) -> NSImage
    /// The apps of the layout that are ticked to be started and still have a zone in it.
    func startApps(of layout: NamedLayout) -> [String]
    /// Starts those of the apps that are not running (they are placed as they open).
    func open(apps bundleIDs: [String])
    func remove(app bundleID: String, in zone: UUID, inZones zones: [UUID])
}
