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

    /// The Dock's tray widened to the whole strip the system keeps free along its edge (the tray stands a few points inside the strip, or outside it).
    /// All in top-left-origin coordinates; `orientation` is the Dock's setting (nil: the bottom).
    static func reserved(_ dock: CGRect, strip: CGFloat, orientation: String?, onDisplay display: CGRect) -> CGRect {
        var wide = dock
        switch orientation {
        case "left": wide.origin.x = display.minX; wide.size.width = strip
        case "right": wide.origin.x = display.maxX - strip; wide.size.width = strip
        default: wide.origin.y = display.maxY - strip; wide.size.height = strip
        }
        return wide
    }

    /// A one point stand-in for a Dock that is not on `display` at its edge, for `reserved` to widen.
    static func standIn(orientation: String?, onDisplay display: CGRect) -> CGRect {
        switch orientation {
        case "left": CGRect(x: display.minX, y: display.midY, width: 1, height: 1)
        case "right": CGRect(x: display.maxX - 1, y: display.midY, width: 1, height: 1)
        default: CGRect(x: display.midX, y: display.maxY - 1, width: 1, height: 1)
        }
    }
}
