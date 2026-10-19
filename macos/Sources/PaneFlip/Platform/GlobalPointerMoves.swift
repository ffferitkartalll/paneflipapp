import AppKit

/// Listens with a global event monitor: it only watches, and costs next to nothing for a move.
final class GlobalPointerMoves: PointerMoveListening {
    private var monitor: Any?

    func start(onMove: @escaping (CGPoint) -> Void) {
        guard monitor == nil else { return }
        monitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { _ in onMove(NSEvent.mouseLocation) }
    }

    func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }
}
