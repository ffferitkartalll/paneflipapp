import AppKit

/// A window's own delegate: it keeps the window from closing, so that a call that reaches it can be told, and counts the sheets that ended.
final class FakeWindowDelegate: NSObject, NSWindowDelegate {
    private(set) var endedSheets = 0

    func windowShouldClose(_ sender: NSWindow) -> Bool { false }

    func windowDidEndSheet(_ notification: Notification) { endedSheets += 1 }
}
