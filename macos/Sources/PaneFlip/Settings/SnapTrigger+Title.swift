import Foundation
import PaneFlipCore

extension SnapTrigger {
    /// The trigger as shown to the user.
    var displayTitle: String {
        keys.map { Self.localizedName(of: $0) }.joined(separator: " + ")
    }

    private static func localizedName(of key: Key) -> String {
        switch key.code {
        case 56: String(localized: "Left Shift")
        case 60: String(localized: "Right Shift")
        case 59: String(localized: "Left Control")
        case 62: String(localized: "Right Control")
        case 58: String(localized: "Left Option")
        case 61: String(localized: "Right Option")
        case 55: String(localized: "Left Command")
        case 54: String(localized: "Right Command")
        case 49: String(localized: "Space")
        case 36: String(localized: "Return")
        case 48: String(localized: "Tab")
        case 51: String(localized: "Delete")
        default: key.name
        }
    }
}
