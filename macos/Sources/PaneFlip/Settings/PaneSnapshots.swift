import AppKit
import SwiftUI

/// Takes a picture of the tab on show, as it looks in its window now.
final class PaneSnapshots {
    weak var view: NSView?

    func image() -> NSImage? {
        guard let view, let window = view.window, window.isVisible, let content = window.contentView else { return nil }
        let rect = view.convert(view.bounds, to: content)
        guard rect.width > 1, rect.height > 1, let rep = content.bitmapImageRepForCachingDisplay(in: rect) else { return nil }
        content.cacheDisplay(in: rect, to: rep)
        let image = NSImage(size: rect.size)
        image.addRepresentation(rep)
        return image
    }
}
