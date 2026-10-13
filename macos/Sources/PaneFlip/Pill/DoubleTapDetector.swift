import AppKit
import PaneFlipCore

/// Detects a quick double tap of one modifier key anywhere in the system. The key is asked for on every event, so
/// a change in the settings applies at once.
final class DoubleTapDetector {
    private let keyCode: () -> Int
    private let interval: TimeInterval
    private let onDoubleTap: () -> Void
    private var lastDown: Date?
    private var monitor: Any?

    init(keyCode: @escaping () -> Int, interval: TimeInterval = 0.4, onDoubleTap: @escaping () -> Void) {
        self.keyCode = keyCode
        self.interval = interval
        self.onDoubleTap = onDoubleTap
    }

    func start() {
        monitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] e in self?.handle(e) }
    }

    private func handle(_ e: NSEvent) {
        let code = keyCode()
        guard Int(e.keyCode) == code, let mask = SnapTrigger.modifierMasks[code],
              e.modifierFlags.rawValue & mask != 0 else { return }   // the key went down
        let now = Date()
        if let last = lastDown, now.timeIntervalSince(last) < interval {
            lastDown = nil
            onDoubleTap()
        } else {
            lastDown = now
        }
    }
}
