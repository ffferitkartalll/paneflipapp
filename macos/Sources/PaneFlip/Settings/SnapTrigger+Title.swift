import Carbon
import Foundation
import PaneFlipCore

extension SnapTrigger {
    /// The trigger as shown to the user.
    var displayTitle: String {
        // The system does not tell the left modifier key from the right one: neither does the title.
        var titles: [String] = []
        for key in keys.enumerated().sorted(by: { (Self.rank(of: $0.element), $0.offset) < (Self.rank(of: $1.element), $1.offset) }).map(\.element) {
            let title = Self.localizedName(of: key)
            if !titles.contains(title) { titles.append(title) }
        }
        return titles.joined(separator: " + ")
    }

    /// Always Caps Lock, Control, Option, Shift, Command, and the key after them, whatever order the keys were pressed in.
    private static func rank(of key: Key) -> Int {
        switch key.code {
        case KeyChord.capsLockKeyCode: -1
        case 59, 62: 0
        case 58, 61: 1
        case 56, 60: 2
        case 55, 54: 3
        default: 4
        }
    }

    private static func localizedName(of key: Key) -> String {
        switch key.code {
        case KeyChord.capsLockKeyCode: String(localized: "Caps Lock") + " (⇪)"
        case 59, 62: String(localized: "Control") + " (⌃)"
        case 58, 61: String(localized: "Option") + " (⌥)"
        case 56, 60: String(localized: "Shift") + " (⇧)"
        case 55, 54: String(localized: "Command") + " (⌘)"
        case 49: String(localized: "Space")
        case 36: String(localized: "Return") + " (↩)"
        case 48: String(localized: "Tab")
        case 51: String(localized: "Delete") + " (⌫)"
        case 53: String(localized: "Escape")
        default: Self.layoutCharacter(of: key.code) ?? key.name
        }
    }

    /// What the key with this code types on the keyboard layout in use, so a shortcut kept as a key code reads as the letter on the
    /// user's own key (the key that is ";" on a US keyboard is "Ş" on a Turkish one). Nil for keys that type nothing printable.
    private static func layoutCharacter(of code: Int) -> String? {
        guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
              let property = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else { return nil }
        let layout = Unmanaged<CFData>.fromOpaque(property).takeUnretainedValue() as Data
        var dead: UInt32 = 0
        var length = 0
        var chars = [UniChar](repeating: 0, count: 4)
        let status = layout.withUnsafeBytes { raw in
            UCKeyTranslate(raw.baseAddress!.assumingMemoryBound(to: UCKeyboardLayout.self), UInt16(code), UInt16(kUCKeyActionDown), 0,
                           UInt32(LMGetKbdType()), OptionBits(kUCKeyTranslateNoDeadKeysBit), &dead, 4, &length, &chars)
        }
        let text = String(utf16CodeUnits: chars, count: length).uppercased()
        let printable = CharacterSet.alphanumerics.union(.punctuationCharacters).union(.symbols)
        guard status == noErr, !text.isEmpty, text.unicodeScalars.allSatisfy(printable.contains) else { return nil }
        return text
    }
}
