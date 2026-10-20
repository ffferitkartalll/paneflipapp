import CoreGraphics
import Foundation

/// How fast the system's trackpad is set to go (System Settings ▸ Trackpad ▸ Tracking speed). A swipe that the fingers lead follows
/// them as the pointer would: the faster the trackpad is set, the further the content goes for the same stroke of the fingers.
struct SystemTrackpadSpeed {
    /// The setting's value when nothing was ever changed.
    static let standard = 0.6875

    /// What the system has now, from 0 (slowest) to 3 (fastest).
    func trackingSpeed() -> Double {
        let value = UserDefaults.standard.persistentDomain(forName: UserDefaults.globalDomain)?["com.apple.trackpad.scaling"] as? Double
        return min(max(value ?? Self.standard, 0), 3)
    }

    /// How many points the content goes for each point of scrolling the fingers make: the system's own speed, and the setting's
    /// multiplier on top (the setting is 2 by default).
    static func gain(forTrackingSpeed speed: Double, multiplier: Double) -> CGFloat {
        CGFloat(2 * multiplier * (1 + min(max(speed, 0), 3)))
    }

    func scrollGain(multiplier: Double) -> CGFloat { Self.gain(forTrackingSpeed: trackingSpeed(), multiplier: multiplier) }
}
