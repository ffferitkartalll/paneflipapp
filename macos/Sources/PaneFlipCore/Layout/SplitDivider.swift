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

    /// The ratio for a line dragged to `position` (on the axis it moves on): no zone smaller than `least` of the rectangle, and the line sticks to
    /// a step of `SplitSnap` that lies within `snapDistance` points.
    public func ratio(forPosition position: CGFloat, snapDistance: Double = 12, least: Double = 0.1) -> Double {
        let raw = min(max(Double((position - (sideBySide ? parent.minX : parent.minY)) / extent), least), 1 - least)
        return SplitSnap.step(near: raw, extent: Double(extent), distance: snapDistance) ?? raw
    }
}
