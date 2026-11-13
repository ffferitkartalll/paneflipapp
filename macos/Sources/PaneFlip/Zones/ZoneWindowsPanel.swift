import AppKit

/// The panel of the grid of a zone's windows: it can take the keyboard (the arrow keys, Return and Escape are the grid's) without the app being activated.
final class ZoneWindowsPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    /// The panel reaches beyond its zone for the shadows: AppKit must not push it back inside the screen (below the menu bar), which would shift the whole grid.
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect { frameRect }
}
