import AppKit

@_silgen_name("CGSMainConnectionID")
private func CGSMainConnectionID() -> Int32

@_silgen_name("CGSSetConnectionProperty")
private func CGSSetConnectionProperty(_ connection: Int32, _ target: Int32, _ key: CFString, _ value: CFTypeRef) -> Int32

/// The nearly clear view of the island's shield: it takes the mouse, and tells where it was pressed, dragged and let go, at the pointer's place in screen
/// coordinates.
final class IslandShieldView: NSView {
    var onPress: ((CGPoint) -> Void)?
    var onDrag: ((CGPoint) -> Void)?
    var onRelease: ((CGPoint) -> Void)?
    /// The pointer's shape over the shield while it is not the arrow (the hand while a card is carried).
    var cursor: NSCursor? {
        didSet {
            // PaneFlip is not the app in front: the window server only takes a shape from such an app when its connection asks for it.
            let connection = CGSMainConnectionID()
            _ = CGSSetConnectionProperty(connection, connection, "SetsCursorInBackground" as CFString, kCFBooleanTrue)
            (cursor ?? .arrow).set()
            window?.invalidateCursorRects(for: self)
        }
    }

    override func mouseDown(with event: NSEvent) { onPress?(NSEvent.mouseLocation) }
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
