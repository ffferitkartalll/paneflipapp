import AppKit
import Observation
import PaneFlipCore
import SwiftUI

/// What the map shows now.
@Observable
final class ScrollPreviewModel {
    var strip = StripLayout(root: .leaf(UUID()))
    var offset = 0.0
    var visible = false
}

/// The map in a small click-through panel in the bottom right corner of the screen, fading in with the scroll and out a moment after it.
final class PanelScrollPreview: ScrollPreviewing {
    private static let margin: CGFloat = 24
    private static let fade: TimeInterval = 0.25

    private let model = ScrollPreviewModel()
    private var panel: NSPanel?
    private var hiding: DispatchWorkItem?
    private var placed: (strip: StripLayout, frame: CGRect)?

    func show(strip: StripLayout, offset: Double, on screen: ScreenInfo) {
        hiding?.cancel()
        let panel = self.panel ?? makePanel()
        let size = StripPreview.size(for: strip)
        let frame = CGRect(x: screen.cocoaVisibleFrame.maxX - size.width - Self.margin, y: screen.cocoaVisibleFrame.minY + Self.margin,
                           width: size.width, height: size.height)
        // Moved and sized only when the strip or the screen is another: this runs on every frame of a scroll.
        if placed?.strip != strip || placed?.frame != frame {
            panel.setFrame(frame, display: true)
            placed = (strip, frame)
        }
        model.strip = strip
        model.offset = offset
        model.visible = true
        if !panel.isVisible { panel.orderFrontRegardless() }
    }

    func hide(after delay: TimeInterval) {
        hiding?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.model.visible = false
            // After the fade the panel leaves the screen too.
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.fade + 0.05) { [weak self] in
                if self?.model.visible == false { self?.panel?.orderOut(nil) }
            }
        }
        hiding = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        panel.contentView = NSHostingView(rootView: ScrollPreviewView(model: model))
        self.panel = panel
        return panel
    }
}

private struct ScrollPreviewView: View {
    let model: ScrollPreviewModel

    var body: some View {
        StripPreview(strip: model.strip, offset: model.offset)
            .opacity(model.visible ? 1 : 0)
            .animation(.easeOut(duration: 0.25), value: model.visible)
    }
}
