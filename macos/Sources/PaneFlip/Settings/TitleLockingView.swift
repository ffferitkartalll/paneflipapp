import AppKit

/// An invisible view that keeps its window's title fixed. SwiftUI renames the Settings window after the selected
/// tab; this puts the title back at once.
final class TitleLockingView: NSView {
    var title = "" {
        didSet { window?.title = title }
    }
    private var observation: NSKeyValueObservation?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        observation = nil
        guard let window else { return }
        window.title = title
        observation = window.observe(\.title, options: [.new]) { [weak self] window, _ in
            guard let self, window.title != self.title else { return }
            window.title = self.title
        }
    }
}
