import Foundation

/// Whether the system will open the app at login.
enum LoginItemStatus: Equatable {
    case enabled
    case disabled
    /// Registered, but the user still has to allow it in System Settings ▸ General ▸ Login Items.
    case requiresApproval
}
