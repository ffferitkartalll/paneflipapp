import AppKit

/// Detects a quick double tap of one modifier key anywhere in the system.
final class DoubleTapDetector {
    private let keyCode: UInt16
    private let deviceMask: UInt
    private let interval: TimeInterval
    private let onDoubleTap: () -> Void
    private var lastDown: Date?
    private var monitor: Any?

    init(keyCode: UInt16, deviceMask: UInt, interval: TimeInterval = 0.4, onDoubleTap: @escaping () -> Void) {
        self.keyCode = keyCode
        self.deviceMask = deviceMask
        self.interval = interval
        self.onDoubleTap = onDoubleTap
    }

    func start() {
        monitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] e in self?.handle(e) }
    }

    private func handle(_ e: NSEvent) {
        guard e.keyCode == keyCode, e.modifierFlags.rawValue & deviceMask != 0 else { return }   // the key went down
        let now = Date()
        if let last = lastDown, now.timeIntervalSince(last) < interval {
            lastDown = nil
            onDoubleTap()
        } else {
            lastDown = now
        }
    }
}
