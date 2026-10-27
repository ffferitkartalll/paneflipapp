import SwiftUI

/// Why a window of a zone is not there: it was closed, its app was hidden, or it was minimized.
enum WindowAbsence {
    case closed, hidden, minimized

    var title: LocalizedStringKey {
        switch self {
        case .closed: "Closed"
        case .hidden: "Hidden"
        case .minimized: "Minimized"
        }
    }
}
