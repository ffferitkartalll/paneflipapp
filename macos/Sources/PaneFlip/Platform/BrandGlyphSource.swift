import AppKit

/// Single-colour brand pictures for applications that the system has no glyph for.
protocol BrandGlyphSource: AnyObject {
    /// The picture for an app if it is known now. An unknown one is looked up in the background and `version`
    /// changes when something new has arrived, so callers redraw.
    func glyph(forApp name: String) -> NSImage?
    var version: Int { get }
}
