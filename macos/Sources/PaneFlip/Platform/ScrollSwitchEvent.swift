import CoreGraphics
import Foundation

/// What the swiping and scrolling is made of.
enum ScrollSwitchEvent: Equatable {
    /// Three fingers (the windows of a zone) or four (the layout) began a swipe on the trackpad; or (`.grid`) a swipe up or down began, whose moves count up as positive.
    case began(ScrollSwitchTarget)
    /// The fingers moved by this much, at this time. To the right (or down) is positive: the content follows the fingers.
    case moved(CGFloat, at: TimeInterval)
    /// The fingers lifted.
    case ended
    /// A turn of the mouse wheel: 1 for a step on, -1 for a step back.
    case step(ScrollSwitchTarget, Int)
}
