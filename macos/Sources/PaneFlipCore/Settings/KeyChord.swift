import Foundation

/// A shortcut as the event tap sees it: which modifier keys are held (left or right alike) and which other key is pressed.
public struct KeyChord: Equatable {

    public let modifiers: Modifiers
    public let keyCode: Int

    public init(modifiers: Modifiers, keyCode: Int) {
        self.modifiers = modifiers
        self.keyCode = keyCode
    }

    /// The key code the Caps Lock key has once the app maps it to F18, which it does while Caps Lock is the app's modifier key.
    public static let capsLockKeyCode = 79

    private static let modifierOfKey: [Int: Modifiers] = [
        59: .control, 62: .control, 58: .option, 61: .option, 55: .command, 54: .command, 56: .shift, 60: .shift,
        capsLockKeyCode: .capsLock,
    ]

    /// The modifier keys a recorded combination of modifier keys alone means; nil when it has any other key, or none.
    public static func modifiers(of trigger: SnapTrigger) -> Modifiers? {
        var result: Modifiers = []
        for key in trigger.keys {
            guard let m = modifierOfKey[key.code] else { return nil }
            result.insert(m)
        }
        return result.isEmpty ? nil : result
    }

    /// The chord a recorded key combination means: one key besides modifier keys, and at least one modifier key (a plain key
    /// would be taken from every app). Nil for anything else.
    public init?(_ trigger: SnapTrigger) {
        var modifiers: Modifiers = []
        var others: [Int] = []
        for key in trigger.keys {
            if let m = Self.modifierOfKey[key.code] { modifiers.insert(m) } else { others.append(key.code) }
        }
        guard others.count == 1, !modifiers.isEmpty else { return nil }
        self.init(modifiers: modifiers, keyCode: others[0])
    }
}
