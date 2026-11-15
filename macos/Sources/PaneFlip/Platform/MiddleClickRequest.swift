import Foundation

/// What a click of the wheel button asks for.
enum MiddleClickRequest: Equatable {
    /// Open or close the grid of the windows of this zone.
    case zone(UUID)
    /// Open or close the grid of the whole layout of every display.
    case layout
}
