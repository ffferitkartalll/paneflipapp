import AppKit

/// The Settings window lets go of its content while it is closed. A closed window keeps its content in memory, and SwiftUI goes on working on it: the form in it costs
/// the scrolls beyond the screen's edge frames. The content is kept aside and comes back as the window opens again.
final class SettingsContentKeeper {
    static let windowIdentifier = NSUserInterfaceItemIdentifier("PaneFlip.settings")

    private var kept: [ObjectIdentifier: NSView] = [:]
    private var observers: [NSObjectProtocol] = []

    func start() {
        let center = NotificationCenter.default
        observers = [
            center.addObserver(forName: NSWindow.willCloseNotification, object: nil, queue: .main) { [weak self] in self?.letGo($0.object as? NSWindow) },
            center.addObserver(forName: NSWindow.didBecomeKeyNotification, object: nil, queue: .main) { [weak self] in self?.bringBack($0.object as? NSWindow) },
            // Before the window is shown, when the app opens it itself: no empty window for a moment.
            center.addObserver(forName: NSApplication.willBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
                self?.kept.keys.forEach { id in NSApp.windows.filter { ObjectIdentifier($0) == id }.forEach { self?.bringBack($0) } }
            },
        ]
    }

    deinit { observers.forEach(NotificationCenter.default.removeObserver) }

    private func letGo(_ window: NSWindow?) {
        // Once the window is out of sight (and the app has gone back to the menu bar): as it is closing, the content is still in use.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self, weak window] in
            guard let self, let window, !window.isVisible, window.identifier == Self.windowIdentifier, kept[ObjectIdentifier(window)] == nil,
                  let content = window.contentView else { return }
            kept[ObjectIdentifier(window)] = content
            window.contentView = NSView()
        }
    }

    private func bringBack(_ window: NSWindow?) {
        guard let window, let content = kept.removeValue(forKey: ObjectIdentifier(window)) else { return }
        window.contentView = content
    }
}
