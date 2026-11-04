import Foundation

/// The notification badges the Dock shows on the icons of apps.
protocol AppBadging {
    /// The badge of each app that has one, by bundle identifier. Asks the Dock, which can take a moment: not for the main thread.
    func badges() -> [String: String]
}
