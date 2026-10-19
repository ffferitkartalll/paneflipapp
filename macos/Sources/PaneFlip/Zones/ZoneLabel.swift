import Foundation
import PaneFlipCore

/// How a zone is named wherever it is shown: 1, 2, 3 on the screen; -1, -2 beyond the left edge; +1, +2 beyond the right one.
enum ZoneLabel {
    static func text(_ position: (part: StripLayout.Part, number: Int)?) -> String {
        guard let position else { return "?" }
        switch position.part {
        case .screen: return "\(position.number)"
        case .leading: return "-\(position.number)"
        case .trailing: return "+\(position.number)"
        }
    }

    static func text(of zone: UUID, in strip: StripLayout) -> String { text(strip.position(of: zone)) }
}
