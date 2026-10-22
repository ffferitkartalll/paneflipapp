import Foundation
import PaneFlipCore

extension TrackpadMethod {
    var title: String {
        switch self {
        case .keysAndTwoFingers: String(localized: "Keys and two fingers")
        case .threeAndFourFingers: String(localized: "Three and four fingers")
        }
    }
}
