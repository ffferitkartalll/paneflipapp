import AppKit
import QuartzCore

/// The picture of a floating zone's window, gliding out to the right with the spring of the slides inside a zone: from behind the window that
/// has the focus (raised over the picture's own panel), never in front of it, and in front of every other window.
final class PanelFloatStage: FloatStaging {
    private let screens: ScreenProviding
    private let panels: StagePanels

    init(screens: ScreenProviding, panels: StagePanels) {
        self.screens = screens
        self.panels = panels
    }

    func slide(_ slide: FloatSlide, started: @escaping () -> Void) {
        let from = screens.flip(slide.from), to = screens.flip(slide.to)
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(CGPoint(x: from.midX, y: from.midY)) }) else { return started() }
        let moving = WindowPictureLayer(slide.picture)
        moving.frame = from.offsetBy(dx: -screen.frame.minX, dy: -screen.frame.minY)
        // With a window to go behind, a panel of its own at the level of the windows (a window that is raised goes over it), in front of all of
        // them for now; else the panel that is over every window.
        let panel = slide.raiseFocused == nil ? panels.panel(for: screen) : Self.panel(on: screen)
        // Not shown until the window that has the focus is over the panel: between the two the picture would show for a moment in front of it.
        moving.opacity = slide.raiseFocused == nil ? 1 : 0
        panel.contentView?.layer?.addSublayer(moving)
        // The window server does not draw a layer that is entirely hidden when it is added (the picture behind the window that has the focus)
        // once it moves into view, unless something else of the panel is in view: four almost clear specks, one in each corner.
        let specks = [CGPoint(x: 0, y: 0), CGPoint(x: screen.frame.width - 24, y: 0), CGPoint(x: 0, y: screen.frame.height - 24),
                      CGPoint(x: screen.frame.width - 24, y: screen.frame.height - 24)].map { corner -> CALayer in
            let speck = CALayer()
            speck.frame = CGRect(origin: corner, size: CGSize(width: 24, height: 24))
            speck.backgroundColor = NSColor.black.withAlphaComponent(0.01).cgColor
            panel.contentView?.layer?.addSublayer(speck)
            return speck
        }
        if slide.raiseFocused != nil { panel.orderFrontRegardless() }
        slide.raiseFocused?()

        // The window that has the focus is raised again a moment later: the window server may have taken the order of the panel after the raise,
        // and the panel would stay over it. Then the picture shows, the real window goes and the picture glides out.
        let raiseAgain = slide.raiseFocused != nil
        if raiseAgain { DispatchQueue.main.asyncAfter(deadline: .now() + 0.04) { slide.raiseFocused?() } }
        DispatchQueue.main.asyncAfter(deadline: .now() + (raiseAgain ? 0.1 : PanelSlideStage.settle)) {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            moving.opacity = 1
            CATransaction.commit()
            started()
            let spring = CASpringAnimation(keyPath: "position.x")
            spring.mass = 1
            spring.stiffness = SlideSpring.stiffness
            spring.damping = SlideSpring.damping
            spring.fromValue = moving.position.x
            spring.toValue = to.midX - screen.frame.minX
            spring.duration = spring.settlingDuration
            spring.fillMode = .forwards
            spring.isRemovedOnCompletion = false
            moving.add(spring, forKey: "slide")
            // Away once the spring is over.
            DispatchQueue.main.asyncAfter(deadline: .now() + spring.duration + 0.1) {
                moving.removeFromSuperlayer()
                specks.forEach { $0.removeFromSuperlayer() }
                if slide.raiseFocused != nil { panel.orderOut(nil) }
            }
        }
    }

    private static func panel(on screen: NSScreen) -> NSPanel {
        let panel = NSPanel(contentRect: screen.frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.level = .normal
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.animationBehavior = .none
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary]
        panel.isReleasedWhenClosed = false
        let view = NSView(frame: CGRect(origin: .zero, size: screen.frame.size))
        view.wantsLayer = true
        panel.contentView = view
        return panel
    }

}
