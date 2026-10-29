import CoreGraphics
import Foundation
import PaneFlipCore

/// Listens with an event tap: it sees the modifier keys come down, and, while a choice is being made, keeps the arrow keys, Return and Escape from the app in front
/// and ends the choice at any other key or click.
final class EventTapPlacementKeys: PlacementKeyListening {
    private var tap: CFMachPort?
    private var onEvent: ((PlacementEvent) -> Void)?
    private var chordHeld = false
    /// The modifier keys of the shortcut as they are now, asked for at every change of the modifier keys.
    private let modifiers: () -> KeyChord.Modifiers?
    /// Whether a choice is being made: only then are keys taken.
    private let isChoosing: () -> Bool

    init(modifiers: @escaping () -> KeyChord.Modifiers?, isChoosing: @escaping () -> Bool) {
        self.modifiers = modifiers
        self.isChoosing = isChoosing
    }

    func start(onEvent: @escaping (PlacementEvent) -> Void) {
        self.onEvent = onEvent
        let callback: CGEventTapCallBack = { _, type, event, refcon in
            guard let refcon else { return Unmanaged.passUnretained(event) }
            return Unmanaged<EventTapPlacementKeys>.fromOpaque(refcon).takeUnretainedValue().handle(type, event)
        }
        let mask = [CGEventType.keyDown, .flagsChanged, .leftMouseDown, .rightMouseDown, .otherMouseDown].reduce(CGEventMask(0)) { $0 | CGEventMask(1 << $1.rawValue) }
        guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap, eventsOfInterest: mask,
                                          callback: callback, userInfo: Unmanaged.passUnretained(self).toOpaque()) else { return }
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
        if type == .flagsChanged {
            let held = modifiers().map { Self.modifiers(of: event.flags) == $0 } ?? false
            if held && !chordHeld { DispatchQueue.main.async { [weak self] in self?.onEvent?(.chord) } }
            chordHeld = held
            return Unmanaged.passUnretained(event)
        }
        guard isChoosing() else { return Unmanaged.passUnretained(event) }
        // Any click, and any key but the keys of the choice, ends it and goes on to the app in front.
        guard type == .keyDown, let key = PlacementKey(keyCode: Int(event.getIntegerValueField(.keyboardEventKeycode))) else {
            DispatchQueue.main.async { [weak self] in self?.onEvent?(.key(.cancel)) }
            return Unmanaged.passUnretained(event)
        }
        // A held arrow key repeats and moves on; Return and Escape act once.
        let repeating = event.getIntegerValueField(.keyboardEventAutorepeat) != 0
        if case .move = key {} else if repeating { return nil }
        DispatchQueue.main.async { [weak self] in self?.onEvent?(.key(key)) }
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
