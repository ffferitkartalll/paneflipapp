import CoreGraphics
import Foundation
import PaneFlipCore

/// Listens with an event tap, which (unlike a monitor) can keep the scrolling from the app under the pointer, and needs only the
/// Accessibility permission the app already has. It hears the mouse wheel with the chosen keys held, and (when the settings ask for it)
/// two fingers on the trackpad with the keys held; and, with no key held, the wheel and two fingers over the open island in the menu bar,
/// which are the layout's (over its picture) or a zone's windows' (over their cards), and over a zone's notch, which are its windows'.
/// Three and four fingers are `MultitouchSwipes`; the scroll the system makes of the first two of them is kept from the app here (`CrowdedScroll`).
final class EventTapScrollSwitch: ScrollSwitchListening {
    private var tap: CFMachPort?
    private var onEvent: ((ScrollSwitchEvent) -> Void)?
    /// Two fingers are down and the keys are held: the swipe has begun and has not ended.
    private var inGesture = false
    /// What the keys held now move, if anything: asked for at every scroll event.
    private let target: () -> ScrollSwitchTarget?
    private var gestureTarget: ScrollSwitchTarget?
    /// The swipe in progress goes up and down, to open and close the grid of a zone's windows (its target is still the one the keys aim at).
    private var lifting = false
    /// How far the content goes for each point the fingers scroll; read when two fingers come down.
    private let gain: () -> CGFloat
    private var gestureGain: CGFloat = 1
    /// Whether the swipe in progress is a horizontal one: decided in its first points, kept to its end.
    private var axis = AxisLock()

    /// Whether the settings let two fingers with the keys held lead the slide.
    private let twoFingers: () -> Bool
    /// What the wheel and two fingers scroll with the pointer on the open island or a zone's notch, if anything: that, whatever the settings and the keys.
    private let overIsland: () -> ScrollSwitchTarget?
    /// How many fingers touch the trackpad: over the island or a notch only exactly two fingers scroll (three and four are `MultitouchSwipes`', and do nothing there).
    private let fingers: () -> Int
    /// Whether a swipe up or down, with the keys that aim at the zone's windows held, may open and close the grid of the zone under the pointer: asked once the swipe is vertical.
    private let grid: () -> Bool
    /// Whether a swipe up or down, with the keys that scroll toward the screens beyond the edges held, may open and close the grid of the whole layout: asked once the swipe is vertical.
    private let layoutGrid: () -> Bool
    /// Whether three or more fingers have been down in the touch in progress, and the settings give them to the app.
    private let crowded: () -> Bool
    private var crowdedScroll = CrowdedScroll()
    /// How the wheel of the user's mouse turns now, if the mouse can say it: asked only for the smooth events with no touch phase that a mouse driver makes of a wheel.
    private let wheelMode: () -> WheelMode?
    /// A smooth wheel in ratchet, turned back into steps.
    private var wheelSteps = WheelSteps()
    /// A smooth wheel in free spin is a swipe that has begun and not ended: with no touch phases it ends when its events stop for `WheelSteps.idle`.
    private var wheelSwipeOpen = false
    private lazy var wheelIdle = WheelIdle { [weak self] in self?.endWheelSwipe() }

    init(gain: @escaping () -> CGFloat, twoFingers: @escaping () -> Bool, overIsland: @escaping () -> ScrollSwitchTarget?, fingers: @escaping () -> Int,
         crowded: @escaping () -> Bool, grid: @escaping () -> Bool, layoutGrid: @escaping () -> Bool, wheelMode: @escaping () -> WheelMode?,
         target: @escaping () -> ScrollSwitchTarget?) {
        self.wheelMode = wheelMode
        self.crowded = crowded
        self.grid = grid
        self.layoutGrid = layoutGrid
        self.gain = gain
        self.twoFingers = twoFingers
        self.overIsland = overIsland
        self.fingers = fingers
        self.target = target
    }

    func start(onEvent: @escaping (ScrollSwitchEvent) -> Void) {
        self.onEvent = onEvent
        let callback: CGEventTapCallBack = { _, type, event, refcon in
            guard let refcon else { return Unmanaged.passUnretained(event) }
            return Unmanaged<EventTapScrollSwitch>.fromOpaque(refcon).takeUnretainedValue().handle(type, event)
        }
        guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
                                          eventsOfInterest: CGEventMask(1 << CGEventType.scrollWheel.rawValue), callback: callback,
                                          userInfo: Unmanaged.passUnretained(self).toOpaque()) else { return }
        self.tap = tap
        CFRunLoopAddSource(CFRunLoopGetMain(), CFMachPortCreateRunLoopSource(nil, tap, 0), .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    private func send(_ event: ScrollSwitchEvent) {
        DispatchQueue.main.async { [weak self] in self?.onEvent?(event) }
    }

    private func handle(_ type: CGEventType, _ event: CGEvent) -> Unmanaged<CGEvent>? {
        // The system switches a tap off when it is too slow once; switch it back on.
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            // The end of a swipe in progress may have gone by while the tap was off: it ends here.
            wheelSwipeOpen = false
            if inGesture {
                inGesture = false
                gestureTarget = nil
                lifting = false
                axis = AxisLock()
                send(.ended)
            }
            return Unmanaged.passUnretained(event)
        }
        guard type == .scrollWheel else { return Unmanaged.passUnretained(event) }
        // Fingers on the trackpad scroll as they always do unless the settings give them to the keys; a mouse wheel is the keys' either way.
        let continuous = event.getIntegerValueField(.scrollWheelEventIsContinuous) != 0
        let phase = event.getIntegerValueField(.scrollWheelEventScrollPhase)   // 1 began, 2 changed, 4 ended, 8 cancelled
        let momentum = event.getIntegerValueField(.scrollWheelEventMomentumPhase)
        // A mouse driver that smooths the wheel sends continuous events with no touch phase at all, which fingers never do. Such a wheel in free spin is a swipe of
        // fingers; in ratchet (or when the mouse cannot say) it is a wheel, the stream of events of a click turned back into a step.
        let kind = WheelKind(continuous: continuous, phase: Int(phase), momentum: Int(momentum), mode: wheelMode)
        let freeSpin = kind == .freeSpin
        let wheel = kind == .notch || kind == .smooth
        // The end of a swipe and the glide after it have no fingers on the trackpad any more; they go on with the swipe they belong to.
        let touching = wheel || freeSpin || phase == 4 || phase == 8 || momentum != 0 || fingers() == 2
        let aimed: ScrollSwitchTarget? = (touching ? overIsland() : nil) ?? (wheel || freeSpin || twoFingers() ? target() : nil)
        // The keys were let go (or others taken) in the middle of a swipe: it ends here.
        if inGesture, aimed != gestureTarget {
            inGesture = false
            gestureTarget = nil
            lifting = false
            axis = AxisLock()
            send(.ended)
        }
        guard let aimed else {
            guard !wheel, !freeSpin else { return Unmanaged.passUnretained(event) }
            switch crowdedScroll.take(crowded: crowded(), phase: Int(phase)) {
            case .pass: return Unmanaged.passUnretained(event)
            case .swallow: return nil
            case .end:
                event.setIntegerValueField(.scrollWheelEventScrollPhase, value: 4)
                for field in [CGEventField.scrollWheelEventDeltaAxis1, .scrollWheelEventDeltaAxis2, .scrollWheelEventPointDeltaAxis1, .scrollWheelEventPointDeltaAxis2,
                              .scrollWheelEventFixedPtDeltaAxis1, .scrollWheelEventFixedPtDeltaAxis2] { event.setIntegerValueField(field, value: 0) }
                return Unmanaged.passUnretained(event)
            }
        }
        // The glide that goes on after the fingers lifted is swallowed too, and means nothing.
        guard momentum == 0 else { return nil }

        if wheel && continuous {
            // A smooth wheel in ratchet: the many small events of a click are one step (`WheelSteps`).
            let points = event.getDoubleValueField(.scrollWheelEventPointDeltaAxis1) + event.getDoubleValueField(.scrollWheelEventPointDeltaAxis2)
            // A driver's points go the other way round than a clicking wheel's: toward you is positive (measured on a Logitech mouse).
            let steps = wheelSteps.add(CGFloat(-points), at: TimeInterval(event.timestamp) / 1e9)
            if steps != 0 { send(.step(aimed, steps)) }
            return nil
        }
        guard continuous else {
            // A mouse wheel has no swipe to follow: each notch is a step.
            let notch = event.getDoubleValueField(.scrollWheelEventDeltaAxis1) + event.getDoubleValueField(.scrollWheelEventDeltaAxis2)
            if notch != 0 { send(.step(aimed, notch < 0 ? -1 : 1)) }   // turned toward you: the previous window; away: the next
            return nil
        }

        // Two fingers: the content follows them to the left and the right, in a swipe that began that way (see `AxisLock`); a swipe that
        // began up or down opens and closes the grid of a zone's windows, if the keys aim at the zone's windows and the pointer is on it.
        let across = CGFloat(event.getDoubleValueField(.scrollWheelEventPointDeltaAxis2))
        let along = CGFloat(event.getDoubleValueField(.scrollWheelEventPointDeltaAxis1))
        if freeSpin {
            // No touch phases: the swipe begins with the first event and ends when they stop (`endWheelSwipe`).
            if !wheelSwipeOpen { wheelSwipeOpen = true; axis = AxisLock() }
            wheelIdle.touch()
        } else if phase == 1 { axis = AxisLock() }
        // A wheel turned toward you is the previous window, as a swipe to the right is (a driver's points are positive toward you); a free spin never goes up or down, which would open the grid by accident.
        let step = freeSpin ? axis.move(horizontal: (across + along) * WheelKind.freeSpinGain, vertical: 0)
                            : axis.move(horizontal: across, vertical: -along)   // the content goes down with the fingers: up is negative
        let finished = !freeSpin && (phase == 4 || phase == 8)
        if !inGesture && !finished {
            let liftZone = axis.decision == .vertical && aimed == .windows && grid()
            let liftLayout = axis.decision == .vertical && aimed == .strip && layoutGrid()
            let lift = liftZone || liftLayout
            let delta = lift ? step.up : step.sideways
            if delta != 0 {
                inGesture = true
                gestureTarget = aimed
                lifting = lift
                gestureGain = gain()
                send(.began(liftLayout ? .layoutGrid : liftZone ? .grid : aimed))
                send(.moved(delta * gestureGain, at: TimeInterval(event.timestamp) / 1e9))
            }
        } else if inGesture && !finished {
            let delta = lifting ? step.up : step.sideways
            if delta != 0 { send(.moved(delta * gestureGain, at: TimeInterval(event.timestamp) / 1e9)) }
        }
        if finished {
            axis = AxisLock()
            if inGesture {
                inGesture = false
                gestureTarget = nil
                lifting = false
                send(.ended)
            }
        }
        return nil
    }

    /// The events of a free-spinning wheel have stopped: its swipe ends, as the lifting of fingers ends one.
    private func endWheelSwipe() {
        wheelSwipeOpen = false
        axis = AxisLock()
        guard inGesture else { return }
        inGesture = false
        gestureTarget = nil
        lifting = false
        send(.ended)
    }
}
