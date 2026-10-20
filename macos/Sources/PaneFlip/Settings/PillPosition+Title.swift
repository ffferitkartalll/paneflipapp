import Foundation
import PaneFlipCore

extension PillPosition {
    var title: String {
        switch self {
        case .top: String(localized: "Top")
        case .bottom: String(localized: "Bottom")
        }
    }
}
