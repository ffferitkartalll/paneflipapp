import SwiftUI

/// A system permission PaneFlip cannot work without.
enum Permission: CaseIterable, Identifiable {
    case accessibility

    var id: Self { self }

    var title: LocalizedStringKey {
        switch self {
        case .accessibility: "Accessibility"
        }
    }

    var detail: LocalizedStringKey {
        switch self {
        case .accessibility: "Lets PaneFlip see the windows of other apps and move them into zones."
        }
    }

    var symbol: String {
        switch self {
        case .accessibility: "accessibility"
        }
    }
}
