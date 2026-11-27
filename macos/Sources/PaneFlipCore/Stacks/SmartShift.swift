/// The words the SmartShift feature of a Logitech mouse (HID++ 2.0, feature 0x2110) is asked in, and how its answers read: the wheel mode of the mouse.
/// Reports are the 20 bytes of a long HID++ report. Pure.
public enum SmartShift {
    /// The number the answers to our questions carry, so that the mouse's other reports are not taken for them.
    private static let softwareID: UInt8 = 0x0A
    /// shortcut: the index of a mouse on Bluetooth; behind a receiver mice are 1 to 6, and are not read, so their wheel mode stays unknown.
    private static let deviceIndex: UInt8 = 0xFF
    private static let feature: UInt16 = 0x2110

    /// The question where the mouse keeps the SmartShift feature.
    public static func featureQuestion() -> [UInt8] { report(feature: 0x00, function: 0, [UInt8(feature >> 8), UInt8(feature & 0xFF)]) }

    /// The question how the wheel turns now, to the feature found at `featureIndex`.
    public static func modeQuestion(featureIndex: UInt8) -> [UInt8] { report(feature: featureIndex, function: 0, []) }

    /// Where the mouse keeps the feature, if `bytes` is the answer to `featureQuestion` and the mouse has it.
    public static func featureIndex(inAnswer bytes: [UInt8]) -> UInt8? {
        guard isAnswer(bytes), bytes[2] == 0x00, bytes[4] != 0 else { return nil }
        return bytes[4]
    }

    /// How the wheel turns, if `bytes` is the answer to `modeQuestion`.
    public static func mode(inAnswer bytes: [UInt8], featureIndex: UInt8) -> WheelMode? {
        guard isAnswer(bytes), bytes[2] == featureIndex else { return nil }
        switch bytes[4] {
        case 1: return .freeSpin
        case 2: return .ratchet
        default: return nil
        }
    }

    private static func isAnswer(_ bytes: [UInt8]) -> Bool {
        bytes.count >= 5 && bytes[0] == 0x11 && bytes[1] == deviceIndex && bytes[3] & 0x0F == softwareID
    }

    private static func report(feature: UInt8, function: UInt8, _ parameters: [UInt8]) -> [UInt8] {
        var out = [UInt8](repeating: 0, count: 20)
        out[0] = 0x11
        out[1] = deviceIndex
        out[2] = feature
        out[3] = function << 4 | softwareID
        for (i, byte) in parameters.enumerated() { out[4 + i] = byte }
        return out
    }
}
