import AppKit
import QuartzCore

/// The scroll's pictures, in one layer that moves as a whole, inside a clip layer cut off at the screen's usable area.
final class PanelScrollStage: ScrollStaging {
    private let screens: ScreenProviding
    private let panels: StagePanels
    private var clip: CALayer?
    private var strip: CALayer?
    private var layers: [CGWindowID: CALayer] = [:]
    private var visible = CGRect.zero
    /// The screen's panel while it stands among the windows, not above them.
    private var raised: NSPanel?

    init(screens: ScreenProviding, panels: StagePanels) {
        self.screens = screens
        self.panels = panels
    }

    func begin(pictures: [ScrollPicture], over visible: CGRect, covered: @escaping () -> Void) {
        remove()
        let cocoa = screens.flip(visible)
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(CGPoint(x: cocoa.midX, y: cocoa.midY)) }) else { return covered() }
        let panel = panels.panel(for: screen)
        guard let root = panel.contentView?.layer else { return covered() }
        // A window that is in no zone and stands in front of the zones' windows stays in front of the pictures too: the panel goes just above the front-most window it
        // covers, not above everything. Windows ordered later (a click on one) are not held.
        let pictured = Set(pictures.map(\.id))
        if let front = CGWindowNumbers.ids(.optionOnScreenOnly).first(where: pictured.contains) {
            panel.level = .normal
            panel.order(.above, relativeTo: Int(front))
            raised = panel
        }
        let clip = CALayer()
        clip.frame = cocoa.offsetBy(dx: -screen.frame.minX, dy: -screen.frame.minY)
        clip.masksToBounds = true
        let strip = CALayer()
        strip.frame = clip.bounds
        self.visible = visible
        self.strip = strip
        for item in pictures { add(item) }
        clip.addSublayer(strip)
        root.addSublayer(clip)
        self.clip = clip
        self.strip = strip
        // A few frames for the window server to put the pictures on screen.
        DispatchQueue.main.asyncAfter(deadline: .now() + PanelSlideStage.settle) { covered() }
    }

    /// A window whose picture was not there when the scroll began (it was out of sight and not photographed yet) gets its
    /// layer now.
    func update(pictures: [ScrollPicture]) {
        guard strip != nil else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for item in pictures {
            if let layer = layers[item.id] { layer.contents = item.picture.image } else { add(item) }
        }
        CATransaction.commit()
    }

    private func add(_ item: ScrollPicture) {
        let picture = item.picture
        let layer = CALayer()
        layer.contents = picture.image
        layer.contentsGravity = .resize
        layer.cornerRadius = picture.cornerRadius
        layer.cornerCurve = .continuous
        layer.masksToBounds = true
        // The layer's origin is bottom-left.
        layer.frame = CGRect(x: picture.frame.minX - visible.minX,
                             y: visible.height - (picture.frame.minY - visible.minY) - picture.frame.height,
                             width: picture.frame.width, height: picture.frame.height)
        strip?.addSublayer(layer)
        layers[item.id] = layer
    }

    func follow(shift: CGFloat) {
        guard let strip, let clip else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        strip.position = CGPoint(x: clip.bounds.midX + shift, y: clip.bounds.midY)
        CATransaction.commit()
    }

    /// Counts the finishes and the calls to keep the pictures: the end of a finish that was called off must not take them away.
    private var finishing = 0

    func finish(completion: @escaping () -> Void) {
        guard let clip else { return completion() }
        finishing += 1
        let mine = finishing
        CATransaction.begin()
        CATransaction.setCompletionBlock { [weak self] in
            guard let self, finishing == mine else { return }
            remove()
            completion()
        }
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 1
        fade.toValue = 0
        fade.duration = PanelSlideStage.fade
        fade.fillMode = .forwards
        fade.isRemovedOnCompletion = false
        clip.add(fade, forKey: "fade")
        CATransaction.commit()
    }

    func keep() {
        finishing += 1
        clip?.removeAnimation(forKey: "fade")
    }

    private func remove() {
        clip?.removeFromSuperlayer()
        raised?.level = StagePanels.level
        raised?.orderFrontRegardless()
        raised = nil
        clip = nil
        strip = nil
        layers = [:]
    }
}
