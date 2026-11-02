import AppKit
import QuartzCore

extension PanelSlideStage {
    /// The slide the fingers lead: the pictures of the zone's windows side by side, and which of them is in front.
    struct Scrubbing {
        let slide: Running
        let layers: [CALayer]
        let current: Int
        let width: CGFloat
    }
}
