import SwiftUI

/// A system permission PaneFlip cannot work without.
enum Permission: CaseIterable, Identifiable {
    case accessibility
    case screenRecording

    var id: Self { self }

    var title: LocalizedStringKey {
        switch self {
        case .accessibility: "Accessibility"
        case .screenRecording: "Screen Recording"
        }
    }

    var detail: LocalizedStringKey {
        switch self {
        case .accessibility: "Lets PaneFlip see the windows of other apps and move them into zones."
        case .screenRecording: "Lets PaneFlip take a picture of a window, so it can slide in beside another one inside its zone."
        }
    }

    var symbol: String {
        switch self {
        case .accessibility: "accessibility"
        case .screenRecording: "record.circle"
        }
    }
}
