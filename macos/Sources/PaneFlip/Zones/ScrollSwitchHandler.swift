import CoreGraphics
import Foundation
import PaneFlipCore

/// Does what the swipe or the scroll asks for: the windows of the zone under the pointer follow three fingers on the trackpad, the layout
/// of the screen toward the zones beyond its edges follows four; a turn of the mouse wheel with the chosen keys held steps.
final class ScrollSwitchHandler {
    /// Without pictures to show it with, a swipe over the screen does one step if the fingers have gone this far.
    private static let stepDistance: CGFloat = 80

    private let coordinator: StackCoordinator
    private let scroller: StripScroller
    private let screens: ScreenProviding
    /// Whether fingers on the trackpad may move this now (the setting is on, nothing else is being placed). The wheel is asked before it is heard.
    private let allows: (ScrollSwitchTarget) -> Bool
    private var target: ScrollSwitchTarget?
    /// The pictures follow the fingers (the windows of a zone, or the layout); when they cannot, `plain` keeps what the fingers did, for the step.
    private var follows = false
    private var plain = ScrubGesture()

    init(coordinator: StackCoordinator, scroller: StripScroller, screens: ScreenProviding, allows: @escaping (ScrollSwitchTarget) -> Bool = { _ in true }) {
        self.allows = allows
        self.coordinator = coordinator
        self.scroller = scroller
        self.screens = screens
    }

    func handle(_ event: ScrollSwitchEvent) {
        switch event {
        case .began(let aimed):
            guard allows(aimed) else { return }   // its moves and its end find no target and do nothing
            target = aimed
            plain = ScrubGesture()
            switch aimed {
            case .windows: follows = coordinator.beginWindowScrub(at: screens.pointerAX)
            case .zoneWindows(let zone): follows = coordinator.stacks[zone].map { coordinator.beginWindowScrub(in: $0) } ?? false
            case .strip: follows = scroller.beginLed()
            }
        case .moved(let delta, let time):
            switch target {
            case .windows, .zoneWindows: if follows { coordinator.moveWindowScrub(by: delta, at: time) } else { plain.add(delta, at: time) }
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
            case .zoneWindows(let zone):
                if follows { coordinator.endWindowScrub() } else if abs(plain.offset) >= Self.stepDistance, let stack = coordinator.stacks[zone] {
                    coordinator.stepWindowScrub(in: stack, by: plain.offset < 0 ? 1 : -1)
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
            case .zoneWindows(let zone): if let stack = coordinator.stacks[zone] { coordinator.stepWindowScrub(in: stack, by: step) }
            case .strip: scroller.scroll(toward: step > 0 ? .right : .left)
            }
        }
    }
}
