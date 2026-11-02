import CoreGraphics
import PaneFlipCore

extension CGEventFlags {
    /// The modifier keys held, as a shortcut sees them. Caps Lock counts while its key is down: it is mapped to F18 then
    /// (`CapsLockControlling`), so it is a key, not a flag of the event.
    func chordModifiers(_ capsLock: CapsLockKeyState) -> KeyChord.Modifiers {
        var result: KeyChord.Modifiers = []
        if contains(.maskControl) { result.insert(.control) }
        if contains(.maskAlternate) { result.insert(.option) }
        if contains(.maskCommand) { result.insert(.command) }
        if contains(.maskShift) { result.insert(.shift) }
        if capsLock.isDown { result.insert(.capsLock) }
        return result
    }
}
