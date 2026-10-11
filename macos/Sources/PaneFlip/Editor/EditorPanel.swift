import AppKit

/// The editor's borderless full-screen panel; it must be able to take keyboard focus for Esc and Return.
final class EditorPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}
