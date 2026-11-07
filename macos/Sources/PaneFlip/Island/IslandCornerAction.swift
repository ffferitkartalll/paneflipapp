import Foundation

/// The buttons in the bar's strip above the picture of the open island, in the order they stand from the left: two at its left edge, two at its right edge
/// (the last one at the corner itself).
enum IslandCornerAction: CaseIterable {
    case editLayout, openApps, settings, quit

    var isOnLeft: Bool { self == .editLayout || self == .openApps }

    var symbol: String {
        switch self {
        case .editLayout: "square.split.2x2.fill"
        case .openApps: "arrow.up.forward.app.fill"
        case .settings: "gearshape.fill"
        case .quit: "power"
        }
    }

    /// The same words as the menu bar menu.
    var title: String {
        switch self {
        case .editLayout: String(localized: "Edit layout")
        case .openApps: String(localized: "Open selected apps")
        case .settings: String(localized: "Settings")
        case .quit: String(localized: "Quit")
        }
    }
}
