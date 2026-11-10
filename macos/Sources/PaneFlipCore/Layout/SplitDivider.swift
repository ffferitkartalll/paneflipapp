import CoreGraphics
import Foundation

/// One split line of a layout tree, as the editor shows and drags it.
public struct SplitDivider: Identifiable, Equatable {
    public let id: UUID
    public let sideBySide: Bool
    /// The rectangle this line divides.
    public let parent: CGRect
    public let ratio: Double

    public init(id: UUID, sideBySide: Bool, parent: CGRect, ratio: Double) {
        self.id = id
        self.sideBySide = sideBySide
        self.parent = parent
        self.ratio = ratio
    }

    /// Length of the divided rectangle along the axis the line moves on.
    public var extent: CGFloat { sideBySide ? parent.width : parent.height }
    public var position: CGFloat { sideBySide ? parent.minX + parent.width * ratio : parent.minY + parent.height * ratio }

    /// The line drawn across `outer` where its rectangle reaches an edge of `inner`: it goes on to the edge of `outer` there (the screen's usable edge, past the margin and the gap's
    /// half), so that it touches the menu bar, the Dock and the display's sides. Only the length of the line changes, never its place.
    public func reaching(_ inner: CGRect, to outer: CGRect) -> SplitDivider {
        func near(_ a: CGFloat, _ b: CGFloat) -> Bool { abs(a - b) < 0.5 }
        var p = parent
        if sideBySide {
            let top = near(p.minY, inner.minY) ? outer.minY : p.minY, bottom = near(p.maxY, inner.maxY) ? outer.maxY : p.maxY
            p = CGRect(x: p.minX, y: top, width: p.width, height: bottom - top)
        } else {
            let left = near(p.minX, inner.minX) ? outer.minX : p.minX, right = near(p.maxX, inner.maxX) ? outer.maxX : p.maxX
            p = CGRect(x: left, y: p.minY, width: right - left, height: p.height)
        }
        return SplitDivider(id: id, sideBySide: sideBySide, parent: p, ratio: ratio)
    }

    /// The ratio for a line dragged to `position` (on the axis it moves on): no zone smaller than `least` of the rectangle, and the line sticks to
    /// a step of `SplitSnap` that lies within `snapDistance` points.
    public func ratio(forPosition position: CGFloat, snapDistance: Double = 12, least: Double = 0.1) -> Double {
        let raw = min(max(Double((position - (sideBySide ? parent.minX : parent.minY)) / extent), least), 1 - least)
        return SplitSnap.step(near: raw, extent: Double(extent), distance: snapDistance) ?? raw
    }
}
