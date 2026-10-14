import CoreGraphics

/// The usable area of a display once the Dock's strip is taken away.
enum DockArea {
    /// `area` without the strip the Dock takes along the edge of `display` it stands at (all in top-left-origin
    /// coordinates). Nothing changes when the Dock is on another display or the system already left room for it.
    static func excluding(_ dock: CGRect?, from area: CGRect, onDisplay display: CGRect) -> CGRect {
        guard let dock, dock.intersects(display) else { return area }
        // The tray stands a few points inside the strip the system reserves: only a real overlap counts.
        let edge: CGFloat = 40, slack: CGFloat = 8
        var usable = area
        if abs(dock.maxY - display.maxY) < edge, dock.minY < usable.maxY - slack {
            usable.size.height = dock.minY - usable.minY
        } else if abs(dock.minX - display.minX) < edge, dock.maxX > usable.minX + slack {
            usable.size.width -= dock.maxX - usable.minX
            usable.origin.x = dock.maxX
        } else if abs(dock.maxX - display.maxX) < edge, dock.minX < usable.maxX - slack {
            usable.size.width = dock.minX - usable.minX
        }
        return usable
    }
}
