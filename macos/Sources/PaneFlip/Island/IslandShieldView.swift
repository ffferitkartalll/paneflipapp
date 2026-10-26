import AppKit

/// The nearly clear view of the island's shield: it takes the mouse, and tells where it was clicked.
final class IslandShieldView: NSView {
    /// A click, at the pointer's place in screen coordinates.
    var onClick: ((CGPoint) -> Void)?

    override func mouseDown(with event: NSEvent) { onClick?(NSEvent.mouseLocation) }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
