import AppKit

/// Listens with a global event monitor: it only watches, and costs next to nothing for a move. The system does not hand a
/// global monitor the moves while this app is the active one (its own Settings window is open, say), so then the pointer is
/// looked at on a short timer instead; reading its place is cheap and asks no app anything.
final class GlobalPointerMoves: PointerMoveListening {
    private var monitor: Any?
    private var observers: [NSObjectProtocol] = []
    private var timer: Timer?

    func start(onMove: @escaping (CGPoint) -> Void) {
        guard monitor == nil else { return }
        monitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { _ in onMove(NSEvent.mouseLocation) }
        let center = NotificationCenter.default
        observers = [
            center.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
                self?.poll(onMove)
            },
            center.addObserver(forName: NSApplication.didResignActiveNotification, object: nil, queue: .main) { [weak self] _ in
                self?.stopPolling()
            },
        ]
        if NSApp.isActive { poll(onMove) }
    }

    func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        observers.forEach(NotificationCenter.default.removeObserver)
        observers = []
        stopPolling()
    }

    private func poll(_ onMove: @escaping (CGPoint) -> Void) {
        stopPolling()
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in onMove(NSEvent.mouseLocation) }
    }

    private func stopPolling() {
        timer?.invalidate()
        timer = nil
    }
}
