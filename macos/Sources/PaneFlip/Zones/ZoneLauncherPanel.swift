import AppKit

/// The panel of a zone's launcher: it is larger than the zone (room for the shadow) and stays where it is put, also where it reaches under the menu bar, which the system
/// would push down.
final class ZoneLauncherPanel: NSPanel {
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect { frameRect }
}
