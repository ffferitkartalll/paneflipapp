import CoreGraphics
import Foundation

extension FingerSwipe {
    public enum Output: Equatable {
        case began(fingers: Int)
        /// The fingers moved by this much (to the right is positive), at this time in seconds.
        case moved(CGFloat, at: TimeInterval)
        case ended
    }
}
