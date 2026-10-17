import CoreGraphics
import Foundation

/// Listens with an event tap, which (unlike a monitor) can keep the key from the app in front, and needs only the
/// Accessibility permission the app already has.
final class EventTapKeyShortcut: KeyShortcutListening {
    private static let leftArrow: Int64 = 123
    private static let rightArrow: Int64 = 124
    private var tap: CFMachPort?
    private var onPress: ((Bool) -> Void)?

    func start(onPress: @escaping (Bool) -> Void) {
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
        let flags = event.flags
        let key = event.getIntegerValueField(.keyboardEventKeycode)
        guard type == .keyDown, key == Self.leftArrow || key == Self.rightArrow,
              flags.contains(.maskControl), flags.contains(.maskAlternate), !flags.contains(.maskCommand), !flags.contains(.maskShift)
        else { return Unmanaged.passUnretained(event) }
        // A held key repeats: it is swallowed too, but moves the selection once.
        if event.getIntegerValueField(.keyboardEventAutorepeat) == 0 {
            let reverse = key == Self.leftArrow
            DispatchQueue.main.async { [weak self] in self?.onPress?(reverse) }
        }
        return nil
    }
}
