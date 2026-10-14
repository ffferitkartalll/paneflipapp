import Foundation
import PaneFlipCore

extension PillContent {
    var title: String {
        switch self {
        case .icon: String(localized: "Icon")
        case .name: String(localized: "Name")
        case .both: String(localized: "Icon and name")
        }
    }
}
