import Foundation

/// Why a window of a zone is not there: its app is not running (quit), or it was closed, its app was hidden, or it was minimized.
enum WindowAbsence {
    case notRunning, closed, hidden, minimized

    var title: String {
        switch self {
        case .notRunning: String(localized: "Not running")
        case .closed: String(localized: "Closed")
        case .hidden: String(localized: "Hidden")
        case .minimized: String(localized: "Minimized")
        }
    }
}
