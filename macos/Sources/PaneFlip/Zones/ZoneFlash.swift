import AppKit

/// Shows where the focus went: a frame in the app's accent colour round the zone it reached, which shows at once and fades. It does not travel from the zone the
/// focus left; round a zone the layout scrolls to, it comes in with the zone's picture (`expect`, `ride`). The frame is a layer faded by Core Animation, which runs by itself: a window that is moved or an app that is brought forward right after
/// cannot make it stutter.
final class ZoneFlash {
    /// How thick the frame is: the frame round a card of the grid of a zone's windows that has the focus is as thick (`ZoneWindowsCard`).
    static let lineWidth: CGFloat = 1
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
        outline.cornerRadius = ZoneCorner.radius
        outline.cornerCurve = .continuous
        outline.borderWidth = Self.lineWidth
        outline.opacity = 0
        view.layer?.addSublayer(outline)
        p.contentView = view
        return p
    }()
    /// Tells a fade that a newer flash has begun, so the older one does not hide it.
    private var generation = 0
    /// The zone a scroll is about to bring into view (where it will stand): its frame waits for the scroll.
    private var expected: CGRect?

    init(screens: ScreenProviding, reduceMotion: @escaping () -> Bool) {
        self.screens = screens
        self.reduceMotion = reduceMotion
    }

    /// The layout is about to scroll `zone` into view (where it will stand, in Accessibility coordinates): the frame waits and comes in with the zone's picture
    /// when the scroll glides (`ride`). When no glide comes (motion is reduced, the scroll could not start) it shows where the zone stands.
    func expect(_ zone: CGRect) {
        expected = zone
        generation += 1
        let mine = generation
        // Longer than the pictures of a scroll take to be made: a glide that comes finds the frame still waiting.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            guard let self, generation == mine, let zone = expected else { return }
            flash(zone)
        }
    }

    /// The layout glides `shift` points to its rest, in the time `duration`: the frame that waits shows `shift` away from its place, where the zone's picture is now,
    /// and goes there with it.
    func ride(by shift: CGFloat, duration: TimeInterval) {
        guard let zone = expected else { return }
        flash(zone, from: reduceMotion() ? 0 : shift, in: duration)
    }

    /// `zone` is a zone in Accessibility coordinates. A frame still showing from the last move goes at once.
    func flash(_ zone: CGRect, from shift: CGFloat = 0, in duration: TimeInterval = 0) {
        expected = nil
        generation += 1
        let mine = generation
        let target = screens.flip(zone)
        guard let screen = screens.screens().first(where: { $0.cocoaFrame.contains(CGPoint(x: target.midX, y: target.midY)) }) else { return }
        let origin = screen.cocoaFrame.origin

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        if panel.frame != screen.cocoaFrame { panel.setFrame(screen.cocoaFrame, display: true) }
        NSApp.effectiveAppearance.performAsCurrentDrawingAppearance { outline.borderColor = AppAccent.nsColor.cgColor }
        outline.frame = target.offsetBy(dx: shift - origin.x, dy: -origin.y)
        outline.opacity = 1
        CATransaction.commit()
        panel.orderFrontRegardless()
        // Out to the render server now, before the caller does anything that keeps the main thread busy.
        CATransaction.flush()
        if shift != 0 {
            // With the picture of its zone, by the same curve (the scroll's glide): the render server moves it by itself.
            CATransaction.begin()
            CATransaction.setAnimationDuration(duration)
            CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(controlPoints: 0.215, 0.61, 0.355, 1))
            outline.frame = target.offsetBy(dx: -origin.x, dy: -origin.y)
            CATransaction.commit()
            CATransaction.flush()
        }

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
