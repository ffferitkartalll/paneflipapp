import CoreGraphics

/// Where a window stands that belongs to a zone outside the screen: on a hidden display of the app's own, where it is out of sight altogether; for the moment
/// of a slide, at the lower corner of an edge of its display (macOS lets a window rest with a single pixel on a display and the rest beyond its left or right edge).
public enum Parking {
    public enum Side: Equatable { case left, right }

    /// Where a window waits that belongs to a zone outside the screen: on a hidden display of its own (`display`, its area), or, for a moment, at the edge of a display.
    public enum Place: Equatable {
        case edge(Side)
        case display(CGRect)
    }

    /// `zone` moved to where it waits at `place`; its size and (at an edge) its height stay.
    public static func frame(for zone: CGRect, on display: CGRect, place: Place) -> CGRect {
        switch place {
        case .edge(let side): return frame(for: zone, on: display, side: side)
        case .display(let area): return CGRect(origin: area.origin, size: zone.size)
        }
    }

    /// Where a window waits for a moment (a slide runs) that belongs to `zone`: at an edge, in the lower corner of the display, where the system keeps only a
    /// sliver of it on the display (it does not let a window go lower), so that what shows is a pixel wide and not the height of the window; at a hidden display, at
    /// its corner. `display` in Accessibility coordinates.
    public static func transitOrigin(for zone: CGRect, on display: CGRect, place: Place) -> CGPoint {
        switch place {
        case .edge(let side): return CGPoint(x: frame(for: zone, on: display, side: side).minX, y: display.maxY - 1)
        case .display(let area): return area.origin
        }
    }

    /// The area of the hidden display of `display`: as large as it, at its lower right corner, touching it by that corner only (the displays stand as a staircase going
    /// up to the right, so nothing lies there; the pointer cannot cross to it, and a window waiting at the corner of `display` has its title bar on it). Nil when that
    /// place is taken (it would overlap one of `others`). All frames in Accessibility coordinates.
    public static func hiddenArea(for display: CGRect, avoiding others: [CGRect]) -> CGRect? {
        let area = CGRect(x: display.maxX, y: display.maxY, width: display.width, height: display.height)
        return others.contains { $0.intersects(area) } ? nil : area
    }

    /// `zone` moved so one pixel of it stays on `display`, at `side`; its size and height stay.
    public static func frame(for zone: CGRect, on display: CGRect, side: Side) -> CGRect {
        let x = side == .right ? display.maxX - 1 : display.minX - zone.width + 1
        return CGRect(x: x, y: zone.minY, width: zone.width, height: zone.height)
    }
}
