import CoreGraphics
import Foundation

extension FingerSwipe {
    public enum Output: Equatable {
        case began(fingers: Int)
        /// A swipe that goes up or down began.
        case liftBegan(fingers: Int)
        /// The fingers moved by this much (to the right is positive; in a swipe up or down, up is), at this time in seconds.
        case moved(CGFloat, at: TimeInterval)
        case ended
    }
}
