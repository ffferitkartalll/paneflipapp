import CoreGraphics
import Foundation

/// What a swipe or a scroll moves: the windows of the zone under the pointer, the layout of the screen toward the zones beyond its edges, or the windows
/// of a zone that the island shows (the pointer is over its cards, not over the zone).
enum ScrollSwitchTarget: Equatable {
    case windows, strip
    /// The grid of the windows of the zone under the pointer, opened and closed by a swipe up and down (the moves are how far the fingers went up).
    case grid
    case zoneWindows(UUID)
}
