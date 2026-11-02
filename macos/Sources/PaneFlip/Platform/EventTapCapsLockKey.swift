import AppKit
import CoreGraphics
import Foundation
import PaneFlipCore

/// Listens with an event tap for the Caps Lock key (mapped to F18 while it is the app's modifier key): the app in front never sees it
/// (except this one, whose shortcut recorder must), and it with Command alone turns the Caps Lock state on or off.
final class EventTapCapsLockKey {
    private var tap: CFMachPort?
    private let state: CapsLockKeyState
    private let isOn: () -> Bool
    private let toggle: () -> Void

    init(state: CapsLockKeyState, isOn: @escaping () -> Bool, toggle: @escaping () -> Void) {
        self.state = state
        self.isOn = isOn
        self.toggle = toggle
    }

    func start() {
        let callback: CGEventTapCallBack = { _, type, event, refcon in
            guard let refcon else { return Unmanaged.passUnretained(event) }
            return Unmanaged<EventTapCapsLockKey>.fromOpaque(refcon).takeUnretainedValue().handle(type, event)
        }
        let mask = [CGEventType.keyDown, .keyUp].reduce(CGEventMask(0)) { $0 | CGEventMask(1 << $1.rawValue) }
        guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap, eventsOfInterest: mask,
                                          callback: callback, userInfo: Unmanaged.passUnretained(self).toOpaque()) else { return }
        self.tap = tap
        CFRunLoopAddSource(CFRunLoopGetMain(), CFMachPortCreateRunLoopSource(nil, tap, 0), .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    private func handle(_ type: CGEventType, _ event: CGEvent) -> Unmanaged<CGEvent>? {
        // The system switches a tap off when it is too slow once; switch it back on (a release may have been missed meanwhile).
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            state.isDown = false
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        guard isOn(), Int(event.getIntegerValueField(.keyboardEventKeycode)) == KeyChord.capsLockKeyCode else {
            if !isOn() { state.isDown = false }
            return Unmanaged.passUnretained(event)
        }
        state.isDown = type == .keyDown
        let others: CGEventFlags = [.maskControl, .maskAlternate, .maskShift, .maskCommand]
        if type == .keyDown, event.getIntegerValueField(.keyboardEventAutorepeat) == 0, event.flags.intersection(others) == .maskCommand {
            DispatchQueue.main.async { [toggle] in toggle() }
        }
        return NSApp.isActive ? Unmanaged.passUnretained(event) : nil
    }
}
