import AppKit

/// Shows where the focus went: a frame that glides from the zone it left to the zone it reached and then fades. With reduced motion it
/// appears at the new zone and goes. The frame is a layer moved by Core Animation, which runs by itself: a window that is moved or an app that
/// is brought forward right after cannot make it stutter.
final class ZoneFlash {
    private let screens: ScreenProviding
    private let reduceMotion: () -> Bool
    private let outline = CALayer()
    private lazy var panel: NSPanel = {
        let p = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        p.level = .floating
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = false
        p.ignoresMouseEvents = true
        p.collectionBehavior = [.canJoinAllSpaces, .stationary]
        let view = NSView()
        view.wantsLayer = true
        outline.cornerRadius = 10
        outline.borderWidth = 5
        outline.opacity = 0
        view.layer?.addSublayer(outline)
        p.contentView = view
        return p
    }()
    /// Tells a fade that a newer flash has begun, so the older one does not hide it.
    private var generation = 0

    init(screens: ScreenProviding, reduceMotion: @escaping () -> Bool) {
        self.screens = screens
        self.reduceMotion = reduceMotion
    }

    /// Both are zones in Accessibility coordinates. A frame still showing from the last move starts from where it is.
    func flash(from old: CGRect, to new: CGRect) {
        generation += 1
        let mine = generation
        let target = screens.flip(new)
        guard let screen = screens.screens().first(where: { $0.cocoaFrame.contains(CGPoint(x: target.midX, y: target.midY)) }) else { return }
        let origin = screen.cocoaFrame.origin
        func local(_ rect: CGRect) -> CGRect { rect.offsetBy(dx: -origin.x, dy: -origin.y) }
        let oldRect = screens.flip(old)
        let moves = !reduceMotion() && screen.cocoaFrame.contains(CGPoint(x: oldRect.midX, y: oldRect.midY))

        let onThisScreen = panel.isVisible && panel.frame == screen.cocoaFrame
        let shown = onThisScreen ? outline.presentation() : nil
        let start = (shown?.opacity ?? 0) > 0.05 ? shown?.frame : nil
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        if panel.frame != screen.cocoaFrame { panel.setFrame(screen.cocoaFrame, display: true) }
        outline.borderColor = NSColor.controlAccentColor.cgColor
        outline.frame = start ?? local(moves ? oldRect : target)
        outline.opacity = 1
        CATransaction.commit()
        panel.orderFrontRegardless()

        let travel = moves ? 0.32 : 0
        CATransaction.begin()
        CATransaction.setAnimationDuration(travel)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeInEaseOut))
        outline.frame = local(target)
        CATransaction.commit()
        // Out to the render server now, before the caller does anything that keeps the main thread busy.
        CATransaction.flush()

        DispatchQueue.main.asyncAfter(deadline: .now() + travel + (moves ? 0.35 : 0.7)) { [weak self] in
            guard let self, generation == mine else { return }
            guard moves else {
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                outline.opacity = 0
                CATransaction.commit()
                return panel.orderOut(nil)
            }
            CATransaction.begin()
            CATransaction.setAnimationDuration(0.7)
            CATransaction.setCompletionBlock { [weak self] in
                if self?.generation == mine { self?.panel.orderOut(nil) }
            }
            outline.opacity = 0
            CATransaction.commit()
        }
    }
}
