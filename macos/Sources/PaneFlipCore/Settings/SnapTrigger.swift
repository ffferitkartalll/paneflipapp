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
    /// Held while scrolling over a zone (two fingers or the wheel), to move through its windows.
    public static let windowScroll = SnapTrigger(keys: [leftOption, leftControl])
    /// Held while scrolling, with two fingers or the wheel, to slide to the zones beyond the screen's edges: the modifier keys of the
    /// shortcuts that do the same from the keyboard.
    public static let stripScroll = SnapTrigger(keys: [commandKey, leftOption, leftControl])
    public static let nextWindow = SnapTrigger(keys: [leftOption, leftControl, rightArrow])
    public static let previousWindow = SnapTrigger(keys: [leftOption, leftControl, leftArrow])
    /// Undo the last action on a window (a window added to a zone, or taken out of one, for now): Control+Option+Delete. The shortcuts that undo actions on
    /// layouts will be this one with Command.
    public static let undoWindow = SnapTrigger(keys: [leftOption, leftControl, Key(code: 51, name: "Delete")])
    /// Close the message that tells what was undone-able: Control+Option+Escape.
    public static let closeWindowUndoNotice = SnapTrigger(keys: [leftOption, leftControl, Key(code: 53, name: "Escape")])
    public static let scrollRight = SnapTrigger(keys: [commandKey, leftOption, leftControl, rightArrow])
    public static let scrollLeft = SnapTrigger(keys: [commandKey, leftOption, leftControl, leftArrow])
    /// Held while typing the number of a zone (or D) to send the focused window there.
    public static let sendToZone = SnapTrigger(keys: [Key(code: 56, name: "Left Shift"), leftOption, leftControl])

    /// Move to the zone above, to the left, below or to the right: Control+Option and I, J, K or L (the four keys form an inverted T; they are named
    /// by their key codes, so the shortcuts stay on the same four keys in every layout).
    private static func letter(_ code: Int, _ name: String) -> Key { Key(code: code, name: name) }
    public static let zoneUp = SnapTrigger(keys: [letter(34, "I"), leftOption, leftControl])
    public static let zoneLeft = SnapTrigger(keys: [letter(38, "J"), leftOption, leftControl])
    public static let zoneDown = SnapTrigger(keys: [letter(40, "K"), leftOption, leftControl])
    public static let zoneRight = SnapTrigger(keys: [letter(37, "L"), leftOption, leftControl])

    /// What the four zone shortcuts were before they moved to I, J, K and L (O, K, L and the key beside L): a stored shortcut that still equals
    /// its former default was never changed by the person, and takes the new default.
    public static let formerZoneUp = SnapTrigger(keys: [letter(31, "O"), leftOption, leftControl])
    public static let formerZoneLeft = SnapTrigger(keys: [letter(40, "K"), leftOption, leftControl])
    public static let formerZoneDown = SnapTrigger(keys: [letter(37, "L"), leftOption, leftControl])
    public static let formerZoneRight = SnapTrigger(keys: [letter(41, ";"), leftOption, leftControl])

    /// Device-dependent flag bits (NX_DEVICE*KEYMASK) for each modifier key code.
    public static let modifierMasks: [Int: UInt] = [56: 0x2, 60: 0x4, 59: 0x1, 62: 0x2000, 58: 0x20, 61: 0x40, 55: 0x8, 54: 0x10]

    /// Stable identifiers, stored with the trigger. They are not shown directly: the app turns the key code into
    /// the text it displays (see `SnapTrigger+Title`).
    public static func name(forKeyCode code: Int, characters: String?) -> String {
        let table: [Int: String] = [
            56: "Left Shift", 60: "Right Shift", 59: "Left Control", 62: "Right Control",
            58: "Left Option", 61: "Right Option", 55: "Left Command", 54: "Right Command",
            49: "Space", 36: "Return", 48: "Tab", 51: "Delete", 53: "Escape", 123: "←", 124: "→", 125: "↓", 126: "↑",
        ]
        if let n = table[code] { return n }
        if let c = characters?.trimmingCharacters(in: .whitespacesAndNewlines), !c.isEmpty { return c.uppercased() }
        return "Key \(code)"
    }
}
