import CoreGraphics
import Foundation

/// What a scroll with the chosen keys held moves: the windows of a zone, or the layout of the screen toward the zones beyond its edges.
enum ScrollSwitchTarget: Equatable {
    case windows, strip
}

/// What the scrolling with the chosen keys held is made of.
enum ScrollSwitchEvent: Equatable {
    /// Two fingers came down on the trackpad.
    case began(ScrollSwitchTarget)
    /// The fingers moved by this much, at this time. To the right (or down) is positive: the content follows the fingers.
    case moved(CGFloat, at: TimeInterval)
    /// The fingers lifted, or the keys were let go.
    case ended
    /// A turn of the mouse wheel: 1 for a step on, -1 for a step back.
    case step(ScrollSwitchTarget, Int)
}

/// The scroll that moves through the windows of a zone, or on to the zones beyond the screen's edges, heard anywhere in the system:
/// with the chosen keys held, two fingers on the trackpad lead the slide and the mouse wheel steps, and the scrolling is not passed
/// on to the app under the pointer.
protocol ScrollSwitchListening {
    /// Starts listening; `onEvent` runs on the main thread. Needs the Accessibility permission.
    func start(onEvent: @escaping (ScrollSwitchEvent) -> Void)
}
