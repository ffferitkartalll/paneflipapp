import CoreGraphics
import Foundation

/// Watches the pointer with an event tap, which needs only the Accessibility permission the app already has, and where it is pushed against the edge of
/// a display and `crossing` names a place beyond, puts it there. The pointer's moves go on to the apps as they are.
final class EventTapPointerCrossing {
    private var tap: CFMachPort?
    /// The place the pointer goes to from a place and the move that pushed it there, if it goes anywhere.
    private let crossing: (CGPoint, CGVector) -> CGPoint?

    init(crossing: @escaping (CGPoint, CGVector) -> CGPoint?) { self.crossing = crossing }

    func start() {
        guard tap == nil else { return }
        let callback: CGEventTapCallBack = { _, type, event, refcon in
            guard let refcon else { return Unmanaged.passUnretained(event) }
            return Unmanaged<EventTapPointerCrossing>.fromOpaque(refcon).takeUnretainedValue().handle(type, event)
        }
        let moves: [CGEventType] = [.mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged]
        guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
                                          eventsOfInterest: moves.reduce(0) { $0 | CGEventMask(1 << $1.rawValue) }, callback: callback,
                                          userInfo: Unmanaged.passUnretained(self).toOpaque()) else { return }
        self.tap = tap
        // The pointer is not held back after it was put somewhere (the system does so for a moment by default).
        CGEventSource(stateID: .combinedSessionState)?.localEventsSuppressionInterval = 0
        CFRunLoopAddSource(CFRunLoopGetMain(), CFMachPortCreateRunLoopSource(nil, tap, 0), .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    private func handle(_ type: CGEventType, _ event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        let delta = CGVector(dx: event.getDoubleValueField(.mouseEventDeltaX), dy: event.getDoubleValueField(.mouseEventDeltaY))
        if let target = crossing(event.location, delta) { CGWarpMouseCursorPosition(target) }
        return Unmanaged.passUnretained(event)
    }
}
