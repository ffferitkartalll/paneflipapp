import AppKit
import Observation
import SwiftUI

/// Lights up every zone on every screen while a window is being dragged with the snap trigger held.
final class SnapZoneOverlay {
    private let model = SnapOverlayModel()
    private let screens: ScreenProviding
    private var panels: [NSPanel] = []

    init(screens: ScreenProviding) { self.screens = screens }

    var isShown: Bool { !panels.isEmpty }

    func show(zones: [(id: UUID, rect: CGRect)]) {
        model.zones = zones.map { SnapOverlayModel.Zone(id: $0.id, cocoaRect: screens.flip($0.rect)) }
        for screen in screens.screens() {
            let p = NSPanel(contentRect: screen.cocoaFrame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            p.level = .floating
            p.isOpaque = false
            p.backgroundColor = .clear
            p.hasShadow = false
            p.ignoresMouseEvents = true
            p.collectionBehavior = [.canJoinAllSpaces, .stationary]
            p.contentView = NSHostingView(rootView: SnapOverlayView(model: model, screenFrame: screen.cocoaFrame))
            p.setFrame(screen.cocoaFrame, display: true)
            p.orderFrontRegardless()
            panels.append(p)
        }
    }

    func highlight(zone id: UUID?) { model.hoverID = id }

    func hide() {
        panels.forEach { $0.orderOut(nil) }
        panels.removeAll()
        model.hoverID = nil
    }
}
