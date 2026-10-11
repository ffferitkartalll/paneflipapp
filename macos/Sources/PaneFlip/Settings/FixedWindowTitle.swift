import SwiftUI

/// Gives the hosting window a title that never changes, whatever the content does.
struct FixedWindowTitle: NSViewRepresentable {
    let title: String

    func makeNSView(context: Context) -> TitleLockingView {
        let view = TitleLockingView()
        view.title = title
        return view
    }

    func updateNSView(_ view: TitleLockingView, context: Context) {
        view.title = title
    }
}
