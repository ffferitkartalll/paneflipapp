import SwiftUI

/// Why a window of a zone is not there: its app is not running (quit), or it was closed, its app was hidden, or it was minimized.
enum WindowAbsence {
    case notRunning, closed, hidden, minimized

    var title: LocalizedStringKey {
        switch self {
        case .notRunning: "Not running"
        case .closed: "Closed"
        case .hidden: "Hidden"
        case .minimized: "Minimized"
        }
    }
}
