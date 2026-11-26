import CoreGraphics
import Foundation

/// Fingers report as often as the trackpad does (a Bluetooth one at an uneven 60 to 90 times a second), not once per refresh of the screen: drawn at each report the
/// pictures would move in uneven steps. They are drawn once per refresh instead, each time on its way to where the fingers are.
enum FingerCatchUp {
    /// The share of the way left falls to a third in this time.
    private static let time: TimeInterval = 0.025
    /// A frame is never taken as longer than this, so a stall does not make the pictures jump.
    private static let longestStep: TimeInterval = 0.05
    /// Closer than this the pictures have arrived.
    static let arrived: CGFloat = 0.25

    /// Where the pictures stand after `elapsed` seconds more, moving from `shown` towards `aim`.
    static func next(from shown: CGFloat, to aim: CGFloat, elapsed: TimeInterval) -> CGFloat {
        abs(aim - shown) < arrived ? aim : shown + (aim - shown) * CGFloat(1 - exp(-min(elapsed, longestStep) / time))
    }
}
