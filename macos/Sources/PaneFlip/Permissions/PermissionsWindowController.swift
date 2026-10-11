import AppKit
import SwiftUI

/// Shows the permission screen in its own window. Closing it without continuing quits the app, since PaneFlip
/// cannot do anything without the permissions.
final class PermissionsWindowController: NSObject, NSWindowDelegate {
    private let activation: ActivationPolicyControlling
    private var window: NSWindow?
    private var finished = false

    init(activation: ActivationPolicyControlling) { self.activation = activation }

    func show(model: PermissionsModel, onContinue: @escaping () -> Void) {
        finished = false
        let view = PermissionsView(
            model: model,
            onContinue: { [weak self] in
                self?.finished = true
                self?.window?.close()
                onContinue()
            },
            onQuit: { NSApp.terminate(nil) })
        let w = NSWindow(contentViewController: NSHostingController(rootView: view))
        w.title = "PaneFlip"
        w.styleMask = [.titled, .closable]
        w.isReleasedWhenClosed = false
        w.delegate = self
        w.center()
        window = w
        activation.windowDidOpen(ObjectIdentifier(w))
        NSApp.activate(ignoringOtherApps: true)
        w.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        if let w = notification.object as? NSWindow { activation.windowDidClose(ObjectIdentifier(w)) }
        if !finished { NSApp.terminate(nil) }
    }
}
