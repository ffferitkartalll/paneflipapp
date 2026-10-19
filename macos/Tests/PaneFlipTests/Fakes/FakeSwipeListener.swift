import PaneFlipCore

final class FakeSwipeListener: TrackpadSwipeListening {
    private(set) var isListening = false
    private var onEvent: ((SwipeTracker.Event) -> Void)?

    func start(onEvent: @escaping (SwipeTracker.Event) -> Void) { isListening = true; self.onEvent = onEvent }
    func stop() { isListening = false; onEvent = nil }
    func send(_ event: SwipeTracker.Event) { onEvent?(event) }
}
