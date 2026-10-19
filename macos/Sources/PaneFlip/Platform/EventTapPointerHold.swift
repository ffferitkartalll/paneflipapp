import CoreGraphics
import Foundation

/// Holds the pointer still with an event tap that swallows its movement. The tap is on only while the pointer is held, so
/// nothing is looked at the rest of the time.
final class EventTapPointerHold: PointerHolding {
    private var tap: CFMachPort?
    private var holding = false

    func hold(_ on: Bool) {
        guard on != holding else { return }
        holding = on
        if tap == nil && on { makeTap() }
        if let tap { CGEvent.tapEnable(tap: tap, enable: on) }
    }

    private func makeTap() {
        let callback: CGEventTapCallBack = { _, type, event, refcon in
            guard let refcon else { return Unmanaged.passUnretained(event) }
            let hold = Unmanaged<EventTapPointerHold>.fromOpaque(refcon).takeUnretainedValue()
            // The system switches a tap off when it is too slow once; switch it back on while the pointer is held.
            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                if hold.holding, let tap = hold.tap { CGEvent.tapEnable(tap: tap, enable: true) }
                return Unmanaged.passUnretained(event)
            }
            return hold.holding ? nil : Unmanaged.passUnretained(event)
        }
        let mask = CGEventMask(1 << CGEventType.mouseMoved.rawValue) | CGEventMask(1 << CGEventType.leftMouseDragged.rawValue)
        guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap, eventsOfInterest: mask,
                                          callback: callback, userInfo: Unmanaged.passUnretained(self).toOpaque()) else { return }
        self.tap = tap
        CFRunLoopAddSource(CFRunLoopGetMain(), CFMachPortCreateRunLoopSource(nil, tap, 0), .commonModes)
    }
}
