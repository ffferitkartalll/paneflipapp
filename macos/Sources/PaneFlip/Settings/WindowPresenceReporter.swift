import AppKit
import SwiftUI

/// Tells an `ActivationPolicyControlling` when the window hosting this view is open, and gives that window the
/// level it should stay at (above other windows, for example).
struct WindowPresenceReporter: NSViewRepresentable {
    let activation: ActivationPolicyControlling
    var level: NSWindow.Level = .normal
    /// Whether the window gets a minimize button (the Settings window of an app does not have one by default).
    var minimizable = false
    /// Follows whether the window is the key window (nil: not asked).
    var isKey: Binding<Bool>?
    /// Given to the window, so that others can tell it.
    var identifier: NSUserInterfaceItemIdentifier?

    func makeNSView(context: Context) -> WindowPresenceView {
        let view = WindowPresenceView()
        view.onOpen = { [activation, level, minimizable, isKey, identifier] in
            $0.level = level
            if let identifier { $0.identifier = identifier }
            if minimizable { $0.styleMask.insert(.miniaturizable) }
            activation.windowDidOpen(ObjectIdentifier($0))
            isKey?.wrappedValue = true
        }
        view.onClose = { [activation, isKey] in
            activation.windowDidClose(ObjectIdentifier($0))
            isKey?.wrappedValue = false
        }
        view.onResign = { [isKey] _ in isKey?.wrappedValue = false }
        return view
    }

    func updateNSView(_ view: WindowPresenceView, context: Context) {}
}
