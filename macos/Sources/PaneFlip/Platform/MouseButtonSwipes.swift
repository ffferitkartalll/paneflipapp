import AppKit
import CoreGraphics

@_silgen_name("CGSMainConnectionID")
private func CGSMainConnectionID() -> Int32

@_silgen_name("CGSSetConnectionProperty")
private func CGSSetConnectionProperty(_ connection: Int32, _ target: Int32, _ key: CFString, _ value: CFTypeRef) -> Int32

/// The wheel button of a mouse, held down and moved to the side, leads the windows of a zone like three fingers do: the mouse is a
/// trackpad then. The pointer stays where it is and shows a hand. A click of the button that never moves is given back to the app under
/// the pointer, so the button keeps its use (a link opened in a new tab) everywhere a swipe could not begin.
final class MouseButtonSwipes: ScrollSwitchListening {
    private static let wheelButton: Int64 = 2
    /// Marks the click given back, so it is not taken again.
    private static let givenBack: Int64 = 0x5061_6E65

    private var tap: CFMachPort?
    private var onEvent: ((ScrollSwitchEvent) -> Void)?
    /// Whether a swipe may begin with the pointer here now.
    private let canBegin: () -> Bool
    /// How far the content goes for each point the mouse moves.
    private let gain: () -> CGFloat
    private var held = false
    private var moved = false
    private var pressedAt = CGPoint.zero

    init(gain: @escaping () -> CGFloat, canBegin: @escaping () -> Bool) {
        self.gain = gain
        self.canBegin = canBegin
    }

    func start(onEvent: @escaping (ScrollSwitchEvent) -> Void) {
        self.onEvent = onEvent
        let callback: CGEventTapCallBack = { _, type, event, refcon in
            guard let refcon else { return Unmanaged.passUnretained(event) }
            return Unmanaged<MouseButtonSwipes>.fromOpaque(refcon).takeUnretainedValue().handle(type, event)
        }
        let mask = [CGEventType.otherMouseDown, .otherMouseUp, .otherMouseDragged].reduce(CGEventMask(0)) { $0 | (1 << $1.rawValue) }
        guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap, eventsOfInterest: mask,
                                          callback: callback, userInfo: Unmanaged.passUnretained(self).toOpaque()) else { return }
        self.tap = tap
        CFRunLoopAddSource(CFRunLoopGetMain(), CFMachPortCreateRunLoopSource(nil, tap, 0), .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    private func send(_ event: ScrollSwitchEvent) {
        DispatchQueue.main.async { [weak self] in self?.onEvent?(event) }
    }

    private func handle(_ type: CGEventType, _ event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            release()   // an event may have been lost with it: the pointer must not stay frozen
            return Unmanaged.passUnretained(event)
        }
        guard event.getIntegerValueField(.mouseEventButtonNumber) == Self.wheelButton,
              event.getIntegerValueField(.eventSourceUserData) != Self.givenBack else { return Unmanaged.passUnretained(event) }
        switch type {
        case .otherMouseDown:
            guard canBegin() else { return Unmanaged.passUnretained(event) }
            held = true
            moved = false
            // The event's place is the mouse's own count, which after a swipe is not where the pointer is: take the pointer's.
            pressedAt = CGEvent(source: nil)?.location ?? event.location
            CGAssociateMouseAndMouseCursorPosition(0)   // the pointer stays; the mouse still reports how far it goes
            showHand()
            return nil
        case .otherMouseDragged where held:
            let dx = CGFloat(event.getDoubleValueField(.mouseEventDeltaX))
            guard dx != 0 else { return nil }
            if !moved {
                moved = true
                send(.began(.windows))
            }
            send(.moved(dx * gain(), at: Double(event.timestamp) / 1_000_000_000))
            showHand()
            return nil
        case .otherMouseUp where held:
            let clicked = !moved
            if moved { send(.ended) }
            release()
            if clicked { giveBackClick(at: pressedAt) }
            return nil
        default:
            return Unmanaged.passUnretained(event)
        }
    }

    private func release() {
        guard held else { return }
        held = false
        CGAssociateMouseAndMouseCursorPosition(1)
        // Joined to the mouse again, the pointer must be where it was left, not where the mouse counts it.
        CGWarpMouseCursorPosition(pressedAt)
        NSCursor.arrow.set()
    }

    /// Another app's pointer is only set from the background when the connection says so.
    private func showHand() {
        let connection = CGSMainConnectionID()
        _ = CGSSetConnectionProperty(connection, connection, "SetsCursorInBackground" as CFString, kCFBooleanTrue)
        NSCursor.closedHand.set()
    }

    private func giveBackClick(at point: CGPoint) {
        for type in [CGEventType.otherMouseDown, .otherMouseUp] {
            guard let click = CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: point, mouseButton: .center) else { continue }
            click.setIntegerValueField(.eventSourceUserData, value: Self.givenBack)
            click.post(tap: .cgSessionEventTap)
        }
    }
}
