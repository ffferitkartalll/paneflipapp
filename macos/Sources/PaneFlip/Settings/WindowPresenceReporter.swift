import AppKit
import SwiftUI

/// Tells an `ActivationPolicyControlling` when the window hosting this view is open.
struct WindowPresenceReporter: NSViewRepresentable {
    let activation: ActivationPolicyControlling
    /// Whether the window gets a minimize button (the Settings window of an app does not have one by default).
    var minimizable = false

    func makeNSView(context: Context) -> WindowPresenceView {
        let view = WindowPresenceView()
        view.onOpen = { [activation, minimizable] in
            if minimizable { $0.styleMask.insert(.miniaturizable) }
            activation.windowDidOpen(ObjectIdentifier($0))
        }
        view.onClose = { [activation] in activation.windowDidClose(ObjectIdentifier($0)) }
        return view
    }

    func updateNSView(_ view: WindowPresenceView, context: Context) {}
}
