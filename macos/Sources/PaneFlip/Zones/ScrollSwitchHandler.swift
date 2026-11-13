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
    private let grid: ZoneWindowsLeading
    /// Whether fingers on the trackpad may move this now (the setting is on, nothing else is being placed). The wheel is asked before it is heard.
    private let allows: (ScrollSwitchTarget) -> Bool
    private var target: ScrollSwitchTarget?
    /// The pictures follow the fingers (the windows of a zone, or the layout); when they cannot, `plain` keeps what the fingers did, for the step.
    private var follows = false
    private var plain = ScrubGesture()
    /// A swipe begins when the fingers have shown which way they go, and only if there is a window (or a screen) that way: toward none it does nothing, the
    /// pictures are not even taken, until the fingers turn back (what they did toward none counts for nothing). What the fingers did meanwhile waits here.
    private var waiting: [(delta: CGFloat, time: TimeInterval)] = []
    private var started = false
    private static let decisionDistance: CGFloat = 2

    init(coordinator: StackCoordinator, scroller: StripScroller, screens: ScreenProviding, grid: ZoneWindowsLeading, allows: @escaping (ScrollSwitchTarget) -> Bool = { _ in true }) {
        self.allows = allows
        self.coordinator = coordinator
        self.scroller = scroller
        self.screens = screens
        self.grid = grid
    }

    func handle(_ event: ScrollSwitchEvent) {
        switch event {
        case .moved(let delta, _) where target == .grid: grid.moveLead(by: delta)
        case .ended where target == .grid:
            grid.endLead()
            target = nil
        case .began(.grid):
            if allows(.grid) { target = .grid }
        case .began(let aimed):
            guard allows(aimed) else { return }   // its moves and its end find no target and do nothing
            target = aimed
            plain = ScrubGesture()
            waiting = []
            started = false
            follows = false
        case .moved(let delta, let time):
            guard let target else { return }
            guard started else {
                // What the fingers do toward nothing counts for nothing: the swipe begins from where they turn back, not from the way they went.
                guard delta != 0, canGo(target, toward: delta) else { waiting = []; return }
                waiting.append((delta, time))
                guard abs(waiting.reduce(0) { $0 + $1.delta }) >= Self.decisionDistance else { return }
                begin(target)
                started = true
                for early in waiting { move(early.delta, early.time, target) }
                waiting = []
                return
            }
            move(delta, time, target)
        case .ended:
            defer { target = nil; follows = false; started = false; waiting = [] }
            guard started else { return }
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
            case .grid: break
            case .strip:
                if follows { scroller.endLed() } else if abs(plain.offset) >= Self.stepDistance {
                    scroller.scroll(toward: plain.offset < 0 ? .right : .left)
                }
            case nil: break
            }
        case .step(let aimed, let step):
            switch aimed {
            // Over a zone with the keys held the wheel goes the other way round from the one over the island's row of cards: toward you is the previous window,
            // away from you the next (the tap's step counts that way).
            case .windows: coordinator.stepWindowScrub(at: screens.pointerAX, by: step)
            case .zoneWindows(let zone): if let stack = coordinator.stacks[zone] { coordinator.stepWindowScrub(in: stack, by: step) }
            case .strip: scroller.scroll(toward: step > 0 ? .right : .left)
            case .grid: break
            }
        }
    }

    /// Whether there is something for fingers going `way` to bring in.
    private func canGo(_ target: ScrollSwitchTarget, toward way: CGFloat) -> Bool {
        switch target {
        case .windows: coordinator.canScrub(at: screens.pointerAX, toward: way)
        case .zoneWindows(let zone): coordinator.stacks[zone].map { coordinator.canScrub(in: $0, toward: way) } ?? false
        case .strip: scroller.canLead(toward: way)
        case .grid: false
        }
    }

    private func begin(_ target: ScrollSwitchTarget) {
        switch target {
        case .windows: follows = coordinator.beginWindowScrub(at: screens.pointerAX)
        case .zoneWindows(let zone): follows = coordinator.stacks[zone].map { coordinator.beginWindowScrub(in: $0) } ?? false
        case .strip: follows = scroller.beginLed()
        case .grid: break
        }
    }

    private func move(_ delta: CGFloat, _ time: TimeInterval, _ target: ScrollSwitchTarget) {
        switch target {
        case .windows, .zoneWindows: if follows { coordinator.moveWindowScrub(by: delta, at: time) } else { plain.add(delta, at: time) }
        case .strip: if follows { scroller.moveLed(by: delta, at: time) } else { plain.add(delta, at: time) }
        case .grid: break
        }
    }
}
