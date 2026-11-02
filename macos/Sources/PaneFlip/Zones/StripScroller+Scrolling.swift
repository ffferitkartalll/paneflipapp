import CoreGraphics
import Foundation
import PaneFlipCore

extension StripScroller {
    struct Scrolling {
        let id: Int
        let screen: ScreenInfo
        let geometry: StripGeometry
        let side: Parking.Side
        let start: CGFloat
        let held: [Held]
        /// The rest position the scroll is heading to.
        var target: CGFloat
        var pictures: [CGWindowID: WindowPicture] = [:]
        /// The photographs of this scroll have come (some window may be missing from them).
        var photographed = false
        var phase = Phase.waiting
        /// Where the pictures are now, between the start and the target.
        var shown: CGFloat
        var glideFrom: CGFloat = 0
        var glideTo: CGFloat = 0
        var glideBegan: TimeInterval = 0
        /// Two fingers lead this scroll: the pictures follow `gesture` until the fingers lift (`released`), then glide on to a rest position.
        var led = false
        var released = false
        var gesture = ScrubGesture()
        /// How far the fingers went before the photographs were on the stage (not counted by the gesture).
        var early: CGFloat = 0
        /// The layout offset the pictures on the stage stand for: where this scroll began, or, for one that took over from another while it
        /// landed, where that one began (the pictures were not laid out again).
        var origin: CGFloat = 0
        /// How far the pictures have moved from where they stand on the stage.
        var shift: CGFloat { origin - shown }
        /// The pictures were on the stage when it landed: it can be taken over.
        var staged = false
        /// Fingers caught a glide on its way: the rest it was heading to, and where the pictures stood when they were caught.
        var heading: CGFloat?
        var caughtAt: CGFloat = 0
    }
}
