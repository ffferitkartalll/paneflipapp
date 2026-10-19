import Foundation

/// A shortcut as the event tap sees it: which modifier keys are held (left or right alike) and which other key is pressed.
public struct KeyChord: Equatable {
    public struct Modifiers: OptionSet {
        public let rawValue: Int
        public init(rawValue: Int) { self.rawValue = rawValue }
        public static let control = Modifiers(rawValue: 1)
        public static let option = Modifiers(rawValue: 2)
        public static let command = Modifiers(rawValue: 4)
        public static let shift = Modifiers(rawValue: 8)
    }

    public let modifiers: Modifiers
    public let keyCode: Int

    public init(modifiers: Modifiers, keyCode: Int) {
        self.modifiers = modifiers
        self.keyCode = keyCode
    }

    private static let modifierOfKey: [Int: Modifiers] = [
        59: .control, 62: .control, 58: .option, 61: .option, 55: .command, 54: .command, 56: .shift, 60: .shift,
    ]

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
