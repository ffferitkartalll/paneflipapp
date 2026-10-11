import PaneFlipCore
import SwiftUI

extension PillContent {
    var title: LocalizedStringKey {
        switch self {
        case .icon: "Icon"
        case .name: "Name"
        case .both: "Icon and name"
        }
    }
}
