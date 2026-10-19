import Foundation

/// The key or key combination that, held while dragging a window, highlights the zones and snaps the window into one.
public struct SnapTrigger: Codable, Equatable {
    public struct Key: Codable, Equatable {
        public let code: Int
        public let name: String

        public init(code: Int, name: String) {
            self.code = code
            self.name = name
        }
    }

    public var keys: [Key]

    public init(keys: [Key]) { self.keys = keys }

    public static let leftCommand = SnapTrigger(keys: [Key(code: 55, name: "Left Command")])

    // The shortcuts that bring the next or previous window of a zone forward, and scroll toward the zones beyond a screen's edge
    // (keys in key-code order, as the recorder makes them).
    private static let leftOption = Key(code: 58, name: "Left Option"), leftControl = Key(code: 59, name: "Left Control")
    private static let commandKey = Key(code: 55, name: "Left Command")
    private static let leftArrow = Key(code: 123, name: "←"), rightArrow = Key(code: 124, name: "→")
    public static let nextWindow = SnapTrigger(keys: [leftOption, leftControl, rightArrow])
    public static let previousWindow = SnapTrigger(keys: [leftOption, leftControl, leftArrow])
    public static let scrollRight = SnapTrigger(keys: [commandKey, leftOption, leftControl, rightArrow])
    public static let scrollLeft = SnapTrigger(keys: [commandKey, leftOption, leftControl, leftArrow])

    /// Device-dependent flag bits (NX_DEVICE*KEYMASK) for each modifier key code.
    public static let modifierMasks: [Int: UInt] = [56: 0x2, 60: 0x4, 59: 0x1, 62: 0x2000, 58: 0x20, 61: 0x40, 55: 0x8, 54: 0x10]

    /// Stable identifiers, stored with the trigger. They are not shown directly: the app turns the key code into
    /// the text it displays (see `SnapTrigger+Title`).
    public static func name(forKeyCode code: Int, characters: String?) -> String {
        let table: [Int: String] = [
            56: "Left Shift", 60: "Right Shift", 59: "Left Control", 62: "Right Control",
            58: "Left Option", 61: "Right Option", 55: "Left Command", 54: "Right Command",
            49: "Space", 36: "Return", 48: "Tab", 51: "Delete", 123: "←", 124: "→", 125: "↓", 126: "↑",
        ]
        if let n = table[code] { return n }
        if let c = characters?.trimmingCharacters(in: .whitespacesAndNewlines), !c.isEmpty { return c.uppercased() }
        return "Key \(code)"
    }
}
