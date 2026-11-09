import AppKit

/// The nearly clear view of the island's shield: it takes the mouse, and tells where it was pressed, dragged and let go, at the pointer's place in screen
/// coordinates.
final class IslandShieldView: NSView {
    var onPress: ((CGPoint) -> Void)?
    var onSecondaryPress: ((CGPoint) -> Void)?
    var onDrag: ((CGPoint) -> Void)?
    var onRelease: ((CGPoint) -> Void)?
    /// The pointer's shape over the shield while it is not the arrow (the hand while a card is carried).
    var cursor: NSCursor? {
        didSet {
            BackgroundCursor.allow()
            (cursor ?? .arrow).set()
            window?.invalidateCursorRects(for: self)
        }
    }

    override func mouseDown(with event: NSEvent) { onPress?(NSEvent.mouseLocation) }
    override func rightMouseDown(with event: NSEvent) { onSecondaryPress?(NSEvent.mouseLocation) }
    override func mouseDragged(with event: NSEvent) {
        cursor?.set()
        onDrag?(NSEvent.mouseLocation)
    }
    override func mouseUp(with event: NSEvent) { onRelease?(NSEvent.mouseLocation) }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    // The shield's panel does not take the focus: the shape is asked for through a tracking area, which works for a window that is not the key one.
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.cursorUpdate, .activeAlways, .inVisibleRect], owner: self))
    }

    override func cursorUpdate(with event: NSEvent) { (cursor ?? .arrow).set() }
}
