import AppKit

/// A window that says a sheet is attached to it without opening one: a real sheet puts a window on the user's screen while the tests run.
final class FakeSheetHost: NSWindow {
    var attached: NSWindow?
    override var attachedSheet: NSWindow? { attached }

    convenience init(width: CGFloat, height: CGFloat) {
        self.init(contentRect: NSRect(x: 0, y: 0, width: width, height: height), styleMask: [.titled], backing: .buffered, defer: true)
    }

    /// The sheet has gone: the window's delegate is told, as the system does.
    func endSheet() {
        attached = nil
        delegate?.windowDidEndSheet?(Notification(name: NSWindow.didEndSheetNotification, object: self))
    }
}
