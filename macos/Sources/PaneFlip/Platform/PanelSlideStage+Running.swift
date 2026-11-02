import AppKit
import QuartzCore

extension PanelSlideStage {
    /// The slide that runs: the clip layer with its pictures, and where each of them comes to rest (the left edge, in the zone).
    final class Running {

        let clip: CALayer
        let zone: CGRect
        let forward: Bool
        var completion: () -> Void
        var items: [Item] = []
        /// Counts the starts and the extensions: a timer of an earlier one must not act on a later one.
        var generation = 0
        var fading = false
        /// The first start has happened (the pictures had their few frames on screen): an extension before it would start it twice.
        var started = false
        /// The slide is the glide of a swipe the fingers led: its pictures, the window they glide to (an index) and the zone's width.
        var swipe: (layers: [CALayer], current: Int, width: CGFloat)?

        init(clip: CALayer, zone: CGRect, forward: Bool, completion: @escaping () -> Void) {
            self.clip = clip
            self.zone = zone
            self.forward = forward
            self.completion = completion
        }
    }
}
