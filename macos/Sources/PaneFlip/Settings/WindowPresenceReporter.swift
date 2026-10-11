import AppKit
import SwiftUI

/// Tells an `ActivationPolicyControlling` when the window hosting this view is open.
struct WindowPresenceReporter: NSViewRepresentable {
    let activation: ActivationPolicyControlling

    func makeNSView(context: Context) -> WindowPresenceView {
        let view = WindowPresenceView()
        view.onOpen = { [activation] in activation.windowDidOpen(ObjectIdentifier($0)) }
        view.onClose = { [activation] in activation.windowDidClose(ObjectIdentifier($0)) }
        return view
    }

    func updateNSView(_ view: WindowPresenceView, context: Context) {}
}
