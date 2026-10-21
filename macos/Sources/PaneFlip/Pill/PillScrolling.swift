import CoreGraphics
import Foundation

/// What a pill asks when it is scrolled over: the windows of its zone follow two fingers on a trackpad, a wheel steps through them.
protocol PillScrolling: AnyObject {
    /// Two fingers moved by `horizontal` and `vertical` points (`began` and `finished` mark the start and the end of the swipe).
    func trackpad(over stack: ZoneStack, horizontal: CGFloat, vertical: CGFloat, began: Bool, finished: Bool, at time: TimeInterval)

    /// A turn of the wheel: toward you (negative) is on to the next window, away from you back.
    func wheel(over stack: ZoneStack, delta: CGFloat)
}
