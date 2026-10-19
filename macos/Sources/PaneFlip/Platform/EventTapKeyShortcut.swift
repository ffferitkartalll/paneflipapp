import CoreGraphics
import Foundation
import PaneFlipCore

/// Listens with an event tap, which (unlike a monitor) can keep the key from the app in front, and needs only the
/// Accessibility permission the app already has.
final class EventTapKeyShortcut: KeyShortcutListening {
    private var tap: CFMachPort?
    private var onPress: ((KeyShortcut) -> Void)?
    /// The shortcuts as they are now: asked for at every key press, so a change in Settings counts at once.
    private let shortcuts: () -> [(KeyShortcut, KeyChord)]

    init(shortcuts: @escaping () -> [(KeyShortcut, KeyChord)]) { self.shortcuts = shortcuts }

    func start(onPress: @escaping (KeyShortcut) -> Void) {
        self.onPress = onPress
        let callback: CGEventTapCallBack = { _, type, event, refcon in
            guard let refcon else { return Unmanaged.passUnretained(event) }
            return Unmanaged<EventTapKeyShortcut>.fromOpaque(refcon).takeUnretainedValue().handle(type, event)
        }
        guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
                                          eventsOfInterest: CGEventMask(1 << CGEventType.keyDown.rawValue), callback: callback,
                                          userInfo: Unmanaged.passUnretained(self).toOpaque()) else { return }
        self.tap = tap
        CFRunLoopAddSource(CFRunLoopGetMain(), CFMachPortCreateRunLoopSource(nil, tap, 0), .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    private func handle(_ type: CGEventType, _ event: CGEvent) -> Unmanaged<CGEvent>? {
        // The system switches a tap off when it is too slow once; switch it back on.
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        guard type == .keyDown else { return Unmanaged.passUnretained(event) }
        let pressed = KeyChord(modifiers: Self.modifiers(of: event.flags), keyCode: Int(event.getIntegerValueField(.keyboardEventKeycode)))
        guard let press = shortcuts().first(where: { $0.1 == pressed })?.0 else { return Unmanaged.passUnretained(event) }
        // A held key repeats: it is swallowed too, but acts once.
        if event.getIntegerValueField(.keyboardEventAutorepeat) == 0 {
            DispatchQueue.main.async { [weak self] in self?.onPress?(press) }
        }
        return nil
    }

    private static func modifiers(of flags: CGEventFlags) -> KeyChord.Modifiers {
        var result: KeyChord.Modifiers = []
        if flags.contains(.maskControl) { result.insert(.control) }
        if flags.contains(.maskAlternate) { result.insert(.option) }
        if flags.contains(.maskCommand) { result.insert(.command) }
        if flags.contains(.maskShift) { result.insert(.shift) }
        return result
    }
}
