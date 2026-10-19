import PaneFlipCore

/// Three fingers moving sideways on the trackpad, heard anywhere in the system.
protocol TrackpadSwipeListening: AnyObject {
    /// Starts listening; `onEvent` runs on the main thread.
    func start(onEvent: @escaping (SwipeTracker.Event) -> Void)
    func stop()
}
