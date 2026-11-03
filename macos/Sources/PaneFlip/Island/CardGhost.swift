import AppKit
import SwiftUI

/// The card carried out of the island's row: its glyph in a round button that follows the pointer over the screen.
final class CardGhost {
    private let panel: NSPanel
    private let model = CardGhostModel()
    private var side: CGFloat { model.icon * 1.6 }

    init() {
        panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 2)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary]
        panel.contentView = NSHostingView(rootView: CardGhostView(model: model))
    }

    /// The card is being carried: the panel stands in front, clear, so that it need not be ordered in and out as the card goes over the row and away from it.
    func begin() {
        guard !panel.isVisible else { return }
        panel.alphaValue = 0
        panel.orderFrontRegardless()
    }

    /// Shows the card with its middle at `point` (Cocoa screen coordinates); `cardSize` is the size of the cards in the row.
    func show(_ card: IslandWindow, cardSize: CGSize, at point: CGPoint) {
        if model.card != card { model.card = card }
        let icon = min(32, cardSize.height * 0.4)
        if model.icon != icon || panel.frame.size != CGSize(width: icon * 1.6, height: icon * 1.6) {
            model.icon = icon
            panel.setContentSize(CGSize(width: side, height: side))
        }
        panel.setFrameOrigin(CGPoint(x: point.x - side / 2, y: point.y - side / 2))
        panel.alphaValue = 1
    }

    /// Clear but in place: the card is over its own row.
    func hideCard() { panel.alphaValue = 0 }

    /// The carrying is over.
    func end() { panel.orderOut(nil) }
}
