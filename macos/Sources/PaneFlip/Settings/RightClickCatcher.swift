import AppKit
import SwiftUI

/// Over a view, tells of a right click on it; every other click goes through to the view.
struct RightClickCatcher: NSViewRepresentable {
    let action: () -> Void

    func makeNSView(context: Context) -> Catcher { Catcher() }

    func updateNSView(_ view: Catcher, context: Context) { view.action = action }
}
