import Foundation
import PaneFlipCore

/// How a zone is named wherever it is shown: 1, 2, 3 on the screen; -1, -2 beyond the left edge and +1, +2 beyond the right one, with a sign more for each screen further out
/// (--1 in the second screen beyond the left edge, ++1 in the second beyond the right).
enum ZoneLabel {
    static func text(of zone: UUID, in strip: StripLayout) -> String {
        guard let position = strip.labelPosition(of: zone) else { return "?" }
        switch position.part {
        case .screen: return "\(position.number)"
        case .leading: return String(repeating: "-", count: position.screens) + "\(position.number)"
        case .trailing: return String(repeating: "+", count: position.screens) + "\(position.number)"
        }
    }
}
