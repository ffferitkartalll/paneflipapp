import AppKit

/// An invisible view that reports when the window hosting it opens and closes.
final class WindowPresenceView: NSView {
    var onOpen: ((NSWindow) -> Void)?
    var onClose: ((NSWindow) -> Void)?
    private var observers: [NSObjectProtocol] = []

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        observers.forEach(NotificationCenter.default.removeObserver)
        observers = []
        guard let window else { return }

        onOpen?(window)
        // A closed window keeps its content; it comes back as "became key", so opening is reported again.
        observers.append(NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification, object: window, queue: .main) { [weak self, weak window] _ in
                if let window { self?.onOpen?(window) }
            })
        observers.append(NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification, object: window, queue: .main) { [weak self, weak window] _ in
                if let window { self?.onClose?(window) }
            })
    }

    deinit { observers.forEach(NotificationCenter.default.removeObserver) }
}
