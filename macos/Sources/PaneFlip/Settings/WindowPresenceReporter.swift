import AppKit
import SwiftUI

/// Tells an `ActivationPolicyControlling` when the window hosting this view is open, and gives that window the
/// level it should stay at (above other windows, for example).
struct WindowPresenceReporter: NSViewRepresentable {
    let activation: ActivationPolicyControlling
    var level: NSWindow.Level = .normal
    /// Whether the window gets a minimize button (the Settings window of an app does not have one by default).
    var minimizable = false

    func makeNSView(context: Context) -> WindowPresenceView {
        let view = WindowPresenceView()
        view.onOpen = { [activation, level, minimizable] in
            $0.level = level
            if minimizable { $0.styleMask.insert(.miniaturizable) }
            activation.windowDidOpen(ObjectIdentifier($0))
        }
        view.onClose = { [activation] in activation.windowDidClose(ObjectIdentifier($0)) }
        return view
    }

    func updateNSView(_ view: WindowPresenceView, context: Context) {}
}
