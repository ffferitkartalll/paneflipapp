import CoreGraphics
import Foundation
import PaneFlipCore

/// Listens with an event tap: it sees the shortcut that begins the choice of a zone, and, while a choice is being made, keeps the arrow keys, Return and Escape
/// from the app in front and ends the choice at any other key or click.
final class EventTapPlacementKeys: PlacementKeyListening {
    private var tap: CFMachPort?
    private var onEvent: ((PlacementEvent) -> Void)?
    private let capsLock: CapsLockKeyState
    /// The shortcut as it is now, asked for at every key press.
    private let chord: () -> KeyChord?
    /// Whether a choice is being made: only then are keys taken.
    private let isChoosing: () -> Bool
    /// Whether the shortcut would begin a choice now: when it would not, the app in front keeps the key.
    private let canBegin: () -> Bool

    init(capsLock: CapsLockKeyState, chord: @escaping () -> KeyChord?, isChoosing: @escaping () -> Bool, canBegin: @escaping () -> Bool) {
        self.capsLock = capsLock
        self.chord = chord
        self.isChoosing = isChoosing
        self.canBegin = canBegin
    }

    func start(onEvent: @escaping (PlacementEvent) -> Void) {
        self.onEvent = onEvent
        let callback: CGEventTapCallBack = { _, type, event, refcon in
            guard let refcon else { return Unmanaged.passUnretained(event) }
            return Unmanaged<EventTapPlacementKeys>.fromOpaque(refcon).takeUnretainedValue().handle(type, event)
        }
        let mask = [CGEventType.keyDown, .leftMouseDown, .rightMouseDown, .otherMouseDown].reduce(CGEventMask(0)) { $0 | CGEventMask(1 << $1.rawValue) }
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
        let code = Int(event.getIntegerValueField(.keyboardEventKeycode))
        guard isChoosing() else {
            // The shortcut begins the choice; the app in front never sees it (a held key repeats: swallowed, acts once).
            guard type == .keyDown, let chord = chord(),
                  KeyChord(modifiers: event.flags.chordModifiers(capsLock), keyCode: code) == chord, canBegin() else { return Unmanaged.passUnretained(event) }
            if event.getIntegerValueField(.keyboardEventAutorepeat) == 0 { DispatchQueue.main.async { [weak self] in self?.onEvent?(.chord) } }
            return nil
        }
        // Any click, and any key but the keys of the choice, ends it and goes on to the app in front.
        guard type == .keyDown, let key = PlacementKey(keyCode: code) else {
            DispatchQueue.main.async { [weak self] in self?.onEvent?(.key(.cancel)) }
            return Unmanaged.passUnretained(event)
        }
        // A held arrow key repeats and moves on; Return and Escape act once.
        let repeating = event.getIntegerValueField(.keyboardEventAutorepeat) != 0
        if case .move = key {} else if repeating { return nil }
        DispatchQueue.main.async { [weak self] in self?.onEvent?(.key(key)) }
        return nil
    }
}
