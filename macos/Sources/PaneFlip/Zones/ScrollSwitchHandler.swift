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
    /// The layout follows the fingers; when it cannot, `plain` keeps what they did, for the step.
    private var layoutFollows = false
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
            switch aimed {
            case .windows: coordinator.beginWindowScrub(at: screens.pointerAX)
            case .strip:
                plain = ScrubGesture()
                layoutFollows = scroller.beginLed()
            }
        case .moved(let delta, let time):
            switch target {
            case .windows: coordinator.moveWindowScrub(by: delta, at: time)
            case .strip:
                if layoutFollows { scroller.moveLed(by: delta, at: time) } else { plain.add(delta, at: time) }
            case nil: break
            }
        case .ended:
            switch target {
            case .windows: coordinator.endWindowScrub()
            case .strip:
                if layoutFollows { scroller.endLed() } else if abs(plain.offset) >= Self.stepDistance {
                    scroller.scroll(toward: plain.offset < 0 ? .right : .left)
                }
            case nil: break
            }
            target = nil
            layoutFollows = false
        case .step(let aimed, let step):
            switch aimed {
            case .windows: coordinator.stepWindows(at: screens.pointerAX, by: step)
            case .strip: scroller.scroll(toward: step > 0 ? .right : .left)
            }
        }
    }
}
