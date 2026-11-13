import Foundation

/// A click of the mouse's wheel button that the app takes: the app in front never sees it.
protocol MiddleClickListening {
    /// Starts listening; `onClick` runs on the main thread. Needs the Accessibility permission.
    func start(onClick: @escaping (UUID) -> Void)
}
