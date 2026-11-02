import AppKit
import SwiftUI

/// An invisible view behind a tab: the place `PaneSnapshots` takes its picture of.
struct PaneSnapshotAnchor: NSViewRepresentable {
    let snapshots: PaneSnapshots

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        snapshots.view = view
        return view
    }

    func updateNSView(_ view: NSView, context: Context) { snapshots.view = view }
}
