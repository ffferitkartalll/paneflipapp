import AppKit
import SwiftUI

/// Tells an `ActivationPolicyControlling` when the window hosting this view is open, and gives that window the
/// level it should stay at (above other windows, for example).
struct WindowPresenceReporter: NSViewRepresentable {
    let activation: ActivationPolicyControlling
    var level: NSWindow.Level = .normal

    func makeNSView(context: Context) -> WindowPresenceView {
        let view = WindowPresenceView()
        view.onOpen = { [activation, level] in
            $0.level = level
            activation.windowDidOpen(ObjectIdentifier($0))
        }
        view.onClose = { [activation] in activation.windowDidClose(ObjectIdentifier($0)) }
        return view
    }

    func updateNSView(_ view: WindowPresenceView, context: Context) {}
}
