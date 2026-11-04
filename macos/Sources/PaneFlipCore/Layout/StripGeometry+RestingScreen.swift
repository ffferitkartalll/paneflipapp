import Foundation

extension StripGeometry {
    /// Which screen of the strip a view at rest shows: the screen's own, or the area `index` (counted from the screen outwards) beyond its left or right edge.
    public enum RestingScreen: Equatable {
        case own
        case leading(Int)
        case trailing(Int)
    }
}
