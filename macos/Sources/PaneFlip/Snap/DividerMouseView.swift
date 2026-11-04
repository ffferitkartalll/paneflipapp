import AppKit

/// The nearly clear view of a handle: it takes the mouse and tells when it is pressed, dragged and let go. It leaves the pointer's shape alone.
final class DividerMouseView: NSView {
    var onPress: (() -> Void)?
    var onDrag: (() -> Void)?
    var onRelease: (() -> Void)?

    override func mouseDown(with event: NSEvent) { onPress?() }
    override func mouseDragged(with event: NSEvent) { onDrag?() }
    override func mouseUp(with event: NSEvent) { onRelease?() }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
