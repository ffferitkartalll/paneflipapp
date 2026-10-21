import CoreGraphics
import Foundation
import PaneFlipCore

/// Does what the scroll with the chosen keys held asks for: the windows of the zone under the pointer, or the layout of the screen
/// toward the zones beyond its edges, follow two fingers on the trackpad; a turn of the mouse wheel steps.
final class ScrollSwitchHandler {
    /// Without pictures to show it with, a swipe over the screen does one step if the fingers have gone this far.
    private static let stepDistance: CGFloat = 80

    private let coordinator: StackCoordinator
    private let scroller: StripScroller
    private let screens: ScreenProviding
    private var target: ScrollSwitchTarget?
    /// The pictures follow the fingers (the windows of a zone, or the layout); when they cannot, `plain` keeps what the fingers did, for the step.
    private var follows = false
    private var plain = ScrubGesture()

    init(coordinator: StackCoordinator, scroller: StripScroller, screens: ScreenProviding) {
        self.coordinator = coordinator
        self.scroller = scroller
        self.screens = screens
    }

    func handle(_ event: ScrollSwitchEvent) {
        switch event {
        case .began(let aimed):
            target = aimed
            plain = ScrubGesture()
            switch aimed {
            case .windows: follows = coordinator.beginWindowScrub(at: screens.pointerAX)
            case .strip: follows = scroller.beginLed()
            }
        case .moved(let delta, let time):
            switch target {
            case .windows: if follows { coordinator.moveWindowScrub(by: delta, at: time) } else { plain.add(delta, at: time) }
            case .strip: if follows { scroller.moveLed(by: delta, at: time) } else { plain.add(delta, at: time) }
            case nil: break
            }
        case .ended:
            switch target {
            case .windows:
                // A swipe the pictures could not follow still moves one window, once it has gone far enough; the step waits for a slide that runs.
                if follows { coordinator.endWindowScrub() } else if abs(plain.offset) >= Self.stepDistance {
                    coordinator.stepWindowScrub(at: screens.pointerAX, by: plain.offset < 0 ? 1 : -1)
                }
            case .strip:
                if follows { scroller.endLed() } else if abs(plain.offset) >= Self.stepDistance {
                    scroller.scroll(toward: plain.offset < 0 ? .right : .left)
                }
            case nil: break
            }
            target = nil
            follows = false
        case .step(let aimed, let step):
            switch aimed {
            // Over a zone with the keys held the wheel goes the other way round from the one over its pill: toward you is the previous window,
            // away from you the next (the tap's step counts that way).
            case .windows: coordinator.stepWindowScrub(at: screens.pointerAX, by: step)
            case .strip: scroller.scroll(toward: step > 0 ? .right : .left)
            }
        }
    }
}
