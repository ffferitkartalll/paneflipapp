import CoreGraphics
import Foundation
import PaneFlipCore

extension StackCoordinator {
    /// One swipe through a zone's windows with two fingers: the pictures of the windows follow the fingers, over as many windows as
    /// they go, and the swipe lets go on one of them when the fingers lift.
    final class WindowScrub {
        let stack: ZoneStack
        let rect: CGRect
        /// A wheel, not fingers, moves it: it lets go this many windows from the one in front, whatever the swipe did.
        var forced: Int?
        /// The windows the swipe passes, in order: those that have a picture (all of them until the pictures are there).
        var windows: [CGWindowID]
        let start: CGWindowID
        var gesture = ScrubGesture()
        /// The pictures are on the stage and follow the fingers.
        var ready = false
        /// There are no pictures (motion is reduced, or the capture failed): the window just comes forward at the end.
        var failed = false
        var ended = false
        /// How far the fingers went before the pictures were on the stage (the gesture does not count it), and whether they lifted before that.
        var early: CGFloat = 0
        var liftedEarly = false

        init(stack: ZoneStack, start: CGWindowID, rect: CGRect) {
            self.stack = stack
            self.start = start
            self.rect = rect
            windows = stack.tabs.map(\.id)
        }
    }
}
