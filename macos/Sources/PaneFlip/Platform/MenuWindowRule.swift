import CoreGraphics

/// Which windows of the window list are a menu or the Dock in use: the menus of menu bar icons and of the Dock are above the ordinary windows (level 101), the Dock's labels are
/// windows of the Dock, and a popover hung from a menu bar icon stands just under the menu bar. A small floating window (a video in a corner) is none of them.
enum MenuWindowRule {
    /// The height of the menu bar's strip, where the icons stand: a window wholly inside it is an icon, not a menu.
    private static let menuBar: CGFloat = 40

    /// A menu can be taller than a thousand points (a long list on a tall display) but is never as wide: a wide window is a bar or a clear panel over a display.
    static func isMenu(layer: Int, owner: String, rect: CGRect) -> Bool {
        guard owner != "Window Server", rect.width > 1, rect.height > 1, rect.width < 1000, rect.maxY > menuBar else { return false }
        return layer >= 101 || (owner == "Dock" && layer >= 3) || (layer >= 24 && rect.minY < 2 * menuBar)
    }
}
