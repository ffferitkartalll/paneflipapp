import AppKit

/// Shows where the focus went: a frame in the app's accent colour round the zone it reached, which shows at once and fades. It does not travel from the zone the
/// focus left. The frame is a layer faded by Core Animation, which runs by itself: a window that is moved or an app that is brought forward right after
/// cannot make it stutter.
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
        outline.borderWidth = 1
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

    /// `zone` is a zone in Accessibility coordinates. A frame still showing from the last move goes at once.
    func flash(_ zone: CGRect) {
        generation += 1
        let mine = generation
        let target = screens.flip(zone)
        guard let screen = screens.screens().first(where: { $0.cocoaFrame.contains(CGPoint(x: target.midX, y: target.midY)) }) else { return }
        let origin = screen.cocoaFrame.origin

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        if panel.frame != screen.cocoaFrame { panel.setFrame(screen.cocoaFrame, display: true) }
        outline.borderColor = AppAccent.nsColor.cgColor
        outline.frame = target.offsetBy(dx: -origin.x, dy: -origin.y)
        outline.opacity = 1
        CATransaction.commit()
        panel.orderFrontRegardless()
        // Out to the render server now, before the caller does anything that keeps the main thread busy.
        CATransaction.flush()

        let reduced = reduceMotion()
        DispatchQueue.main.asyncAfter(deadline: .now() + (reduced ? 0.7 : 0.35)) { [weak self] in
            guard let self, generation == mine else { return }
            CATransaction.begin()
            if reduced { CATransaction.setDisableActions(true) } else { CATransaction.setAnimationDuration(0.7) }
            CATransaction.setCompletionBlock { [weak self] in
                if self?.generation == mine { self?.panel.orderOut(nil) }
            }
            outline.opacity = 0
            CATransaction.commit()
        }
    }
}
