import CoreGraphics
import Foundation
import PaneFlipCore

/// Scrolling over a pill. With two fingers the pictures of the zone's windows follow them over as many windows as they go (up or down
/// as well as left and right: the swipe takes the direction it began in), and come to rest on the nearest one when the fingers lift; a swipe
/// can begin again before they have. A wheel moves one window for each turn, also while the pictures of the last one are on their way.
final class PillScrollRouter: PillScrolling {
    /// Without pictures to show it with, a swipe does one step if the fingers have gone this far.
    private static let stepDistance: CGFloat = 80

    private let coordinator: StackCoordinator
    /// How far the content goes for each point the fingers scroll; read when two fingers come down.
    private let gain: () -> CGFloat
    private var axis = AxisLock()
    /// The swipe has begun (its first move was made): the pictures follow it, or, when they cannot, `plain` keeps what it did for a step.
    private var inSwipe = false
    private var follows = false
    private var gestureGain: CGFloat = 1
    private var plain = ScrubGesture()

    init(coordinator: StackCoordinator, gain: @escaping () -> CGFloat) {
        self.coordinator = coordinator
        self.gain = gain
    }

    func trackpad(over stack: ZoneStack, horizontal: CGFloat, vertical: CGFloat, began: Bool, finished: Bool, at time: TimeInterval) {
        if began { axis = AxisLock() }
        let sideways = axis.add(horizontal: horizontal, vertical: vertical)
        let delta = axis.decision == .vertical ? vertical : sideways
        if !inSwipe, !finished, delta != 0 {
            inSwipe = true
            gestureGain = gain()
            plain = ScrubGesture()
            follows = coordinator.beginWindowScrub(in: stack)
        }
        if inSwipe, !finished, delta != 0 {
            if follows { coordinator.moveWindowScrub(by: delta * gestureGain, at: time) } else { plain.add(delta * gestureGain, at: time) }
        }
        guard finished else { return }
        if inSwipe {
            if follows { coordinator.endWindowScrub() }
            else if abs(plain.offset) >= Self.stepDistance { coordinator.stepWindowScrub(in: stack, by: plain.offset < 0 ? 1 : -1) }
        }
        inSwipe = false
        follows = false
        axis = AxisLock()
    }

    func wheel(over stack: ZoneStack, delta: CGFloat) {
        coordinator.stepWindowScrub(in: stack, by: PagedScroll.notch(delta))
    }
}
