import AppKit
import CoreGraphics

@_silgen_name("CGSMainConnectionID")
private func CGSMainConnectionID() -> Int32

@_silgen_name("CGSSetConnectionProperty")
private func CGSSetConnectionProperty(_ connection: Int32, _ target: Int32, _ key: CFString, _ value: CFTypeRef) -> Int32

/// The wheel button of a mouse, held down and moved to the side, leads the windows of a zone like three fingers do: the mouse is a
/// trackpad then. Nothing happens until the mouse moves: the button pressed and let go is given back to the app under the pointer as the click
/// it is (a tab closed, a link opened in a new tab). From the first move the pointer stays where it was pressed and shows a hand. The pointer
/// is only held still for good while this app is the active one, so it takes the focus for the swipe; the window that comes to the front at
/// its end takes the focus back (`StackCoordinator`), and the app that had it is given it back if no window does.
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
    /// The app under the pointer set its own pointer at every move: the hand is set again right after, for as long as the swipe lasts.
    private var handTimer: Timer?
    /// The app that was in front when the swipe began.
    private var previousApp: NSRunningApplication?
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
            pressedAt = CGEvent(source: nil)?.location ?? event.location   // where the pointer is: the count of the mouse may be elsewhere
            return nil   // kept until it is known whether this is a click or a swipe
        case .otherMouseDragged where held:
            let dx = CGFloat(event.getDoubleValueField(.mouseEventDeltaX))
            guard dx != 0 || moved else { return nil }
            if !moved {
                moved = true
                previousApp = NSWorkspace.shared.frontmostApplication
                NSRunningApplication.current.activate(options: [.activateIgnoringOtherApps])
                CGAssociateMouseAndMouseCursorPosition(0)   // the pointer stays; the mouse still reports how far it goes
                showHand()
                handTimer = Timer.scheduledTimer(withTimeInterval: 0.03, repeats: true) { [weak self] _ in self?.showHand() }
                send(.began(.windows))
            }
            if dx != 0 { send(.moved(dx * gain(), at: ProcessInfo.processInfo.systemUptime)) }   // the event's own stamp is in machine ticks
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
        handTimer?.invalidate()
        handTimer = nil
        guard moved else { return }
        CGAssociateMouseAndMouseCursorPosition(1)
        // Joined to the mouse again, the pointer must be where it was left, not where the mouse counts it.
        CGWarpMouseCursorPosition(pressedAt)
        NSCursor.arrow.set()
        // The window that comes to the front takes the focus (when its pictures have settled); if none does, the app that had it gets it back.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in self?.giveFocusBack() }
    }

    private func giveFocusBack() {
        defer { previousApp = nil }
        guard !held, NSApp.isActive, NSApp.keyWindow == nil, let previous = previousApp, previous != NSRunningApplication.current else { return }
        previous.activate()
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
