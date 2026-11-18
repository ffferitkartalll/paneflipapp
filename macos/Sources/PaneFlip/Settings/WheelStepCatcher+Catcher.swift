import AppKit

extension WheelStepCatcher {
    final class Catcher: NSView {
        var step: (CGFloat) -> Bool = { _ in false }
        private var monitor: Any?
        private var last = Date.distantPast

        override func hitTest(_ point: NSPoint) -> NSView? { nil }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            stopWatching()
            guard window != nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in self?.take(event) ?? event }
        }

        func stopWatching() {
            if let monitor { NSEvent.removeMonitor(monitor) }
            monitor = nil
        }

        /// One notch of a wheel moves one step; the turns that follow within a moment (a wheel spun fast) belong to it.
        private func take(_ event: NSEvent) -> NSEvent? {
            guard event.window === window, !event.hasPreciseScrollingDeltas, bounds.contains(convert(event.locationInWindow, from: nil)) else { return event }
            let delta = abs(event.scrollingDeltaY) >= abs(event.scrollingDeltaX) ? event.scrollingDeltaY : event.scrollingDeltaX
            guard delta != 0 else { return event }
            if Date().timeIntervalSince(last) < 0.12 { return nil }
            guard step(delta) else { return event }
            last = Date()
            return nil
        }
    }
}
