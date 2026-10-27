import AppKit

/// A card of the row under the picture: a window of the zone chosen in the picture, or an app of that zone that shows none (it is not open).
struct IslandWindow: Identifiable, Equatable {
    /// The window; nil for an app that is not open: a click opens it.
    let windowID: CGWindowID?
    let bundleID: String
    let name: String
    /// The single-colour picture of its app that the pill draws.
    let glyph: NSImage?
    /// Changes when a brand glyph arrives, so that the picture is made again.
    let glyphRevision: Int
    /// Why an app that is not open shows no window; nil for a window.
    let absence: WindowAbsence?
    /// The window in front in its zone.
    let isActive: Bool

    var id: String { windowID.map { "w\($0)" } ?? "a\(bundleID)" }

    static func == (a: IslandWindow, b: IslandWindow) -> Bool {
        a.id == b.id && a.absence == b.absence && a.name == b.name && a.glyphRevision == b.glyphRevision && a.isActive == b.isActive
    }
}
