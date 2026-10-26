import AppKit

/// A window of the zone chosen in the picture, as the frame under the picture shows it.
struct IslandWindow: Identifiable, Equatable {
    let id: CGWindowID
    let name: String
    /// The single-colour picture of its app that the pill draws.
    let glyph: NSImage?
    /// Changes when a brand glyph arrives, so that the picture is made again.
    let glyphRevision: Int
    /// The window in front in its zone.
    let isActive: Bool

    static func == (a: IslandWindow, b: IslandWindow) -> Bool {
        a.id == b.id && a.name == b.name && a.glyphRevision == b.glyphRevision && a.isActive == b.isActive
    }
}
