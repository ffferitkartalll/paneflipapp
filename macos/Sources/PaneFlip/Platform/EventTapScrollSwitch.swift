import CoreGraphics
import Foundation
import PaneFlipCore

/// Listens with an event tap, which (unlike a monitor) can keep the scrolling from the app under the pointer, and needs only the
/// Accessibility permission the app already has.
final class EventTapScrollSwitch: ScrollSwitchListening {
    private var tap: CFMachPort?
    private var onEvent: ((ScrollSwitchEvent) -> Void)?
    /// Two fingers are down and the keys are held: the swipe has begun and has not ended.
    private var inGesture = false
    /// What the keys held now move, if anything: asked for at every scroll event.
    private let target: () -> ScrollSwitchTarget?
    private var gestureTarget: ScrollSwitchTarget?
    /// How far the content goes for each point the fingers scroll; read when two fingers come down.
    private let gain: () -> CGFloat
    private var gestureGain: CGFloat = 1
    /// Whether the swipe in progress is a horizontal one: decided in its first points, kept to its end.
    private var axis = AxisLock()

    init(gain: @escaping () -> CGFloat, target: @escaping () -> ScrollSwitchTarget?) {
        self.gain = gain
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
            return Unmanaged.passUnretained(event)
        }
        guard type == .scrollWheel else { return Unmanaged.passUnretained(event) }
        let aimed = target()
        // The keys were let go (or others taken) in the middle of a swipe: it ends here.
        if inGesture, aimed != gestureTarget {
            inGesture = false
            gestureTarget = nil
            axis = AxisLock()
            send(.ended)
        }
        guard let aimed else { return Unmanaged.passUnretained(event) }
        // The glide that goes on after the fingers lifted is swallowed too, and means nothing.
        guard event.getIntegerValueField(.scrollWheelEventMomentumPhase) == 0 else { return nil }

        guard event.getIntegerValueField(.scrollWheelEventIsContinuous) != 0 else {
            // A mouse wheel has no swipe to follow: each notch is a step.
            let notch = event.getDoubleValueField(.scrollWheelEventDeltaAxis1) + event.getDoubleValueField(.scrollWheelEventDeltaAxis2)
            if notch != 0 { send(.step(aimed, notch < 0 ? -1 : 1)) }   // turned toward you: the previous window; away: the next
            return nil
        }

        // Two fingers: the content follows them to the left and the right, in a swipe that began that way (see `AxisLock`); a swipe that
        // began up or down moves nothing, however it goes on.
        let phase = event.getIntegerValueField(.scrollWheelEventScrollPhase)   // 1 began, 2 changed, 4 ended, 8 cancelled
        if phase == 1 { axis = AxisLock() }
        let delta = axis.add(horizontal: CGFloat(event.getDoubleValueField(.scrollWheelEventPointDeltaAxis2)),
                             vertical: CGFloat(event.getDoubleValueField(.scrollWheelEventPointDeltaAxis1)))
        let finished = phase == 4 || phase == 8
        if !inGesture && !finished && delta != 0 {
            inGesture = true
            gestureTarget = aimed
            gestureGain = gain()
            send(.began(aimed))
        }
        if delta != 0 && !finished { send(.moved(delta * gestureGain, at: TimeInterval(event.timestamp) / 1e9)) }
        if finished {
            axis = AxisLock()
            if inGesture {
                inGesture = false
                gestureTarget = nil
                send(.ended)
            }
        }
        return nil
    }
}
