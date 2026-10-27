import AppKit
import QuartzCore

/// A transparent panel over each screen, always on screen and click-through. A slide only adds a layer to it, cut
/// off at the zone's edge and rounded like the windows. The panel itself never appears or disappears while a slide
/// runs: a window that turns up while the island's front card moves disturbs the island for a few frames.
/// The animation runs in the render server, not in the app: it does not stutter when the app is busy.
final class PanelSlideStage: SlideStaging {
    /// A spring, like the front card of the island: it starts quickly and lands softly, without the long standstill at the end
    /// of an ease-in-out curve. Critically damped: no overshoot.
    static let stiffness = SlideSpring.stiffness
    static let damping = SlideSpring.damping
    /// The hand-over to the real window starts this far into the slide (of its settling time), while the picture is
    /// all but at rest: the last part of a spring only creeps.
    static let handOver = 0.7
    /// The pictures give way to the real windows with a short fade: the real window is active and has its own
    /// shadow, the picture does not.
    static let fade: CFTimeInterval = 0.22
    /// How long the pictures get to appear before the real windows change.
    static let settle: TimeInterval = 0.033

    private let screens: ScreenProviding
    private let panels: StagePanels

    init(screens: ScreenProviding, panels: StagePanels) {
        self.screens = screens
        self.panels = panels
    }

    /// Puts the panels on screen: done once, a moment after the app has started and while nothing else is being set up,
    /// not when the island opens (a window made at that moment can upset it while it lays itself out).
    func prepare() { NSScreen.screens.forEach { _ = panels.panel(for: $0) } }

    /// The slide that runs: the clip layer with its pictures, and where each of them comes to rest (the left edge, in the zone).
    private final class Running {
        struct Item {
            let layer: CALayer
            var restLeft: CGFloat
        }

        let clip: CALayer
        let zone: CGRect
        let forward: Bool
        var completion: () -> Void
        var items: [Item] = []
        /// Counts the starts and the extensions: a timer of an earlier one must not act on a later one.
        var generation = 0
        var fading = false
        /// The first start has happened (the pictures had their few frames on screen): an extension before it would start it twice.
        var started = false
        /// The slide is the glide of a swipe the fingers led: its pictures, the window they glide to (an index) and the zone's width.
        var swipe: (layers: [CALayer], current: Int, width: CGFloat)?

        init(clip: CALayer, zone: CGRect, forward: Bool, completion: @escaping () -> Void) {
            self.clip = clip
            self.zone = zone
            self.forward = forward
            self.completion = completion
        }
    }

    private var running: Running?

    /// The slide the fingers lead: the pictures of the zone's windows side by side, and which of them is in front.
    private struct Scrubbing {
        let slide: Running
        let layers: [CALayer]
        let current: Int
        let width: CGFloat
    }
    private var scrubbing: Scrubbing?

    func beginScrub(pictures: [WindowPicture], current: Int, in zone: CGRect) -> Bool {
        let cocoaZone = screens.flip(zone)
        guard scrubbing == nil, running == nil, pictures.indices.contains(current),
              let screen = NSScreen.screens.max(by: { overlap($0.frame, cocoaZone) < overlap($1.frame, cocoaZone) }),
              overlap(screen.frame, cocoaZone) > 0, let root = panels.panel(for: screen).contentView?.layer else { return false }
        let clip = CALayer()
        clip.frame = cocoaZone.offsetBy(dx: -screen.frame.minX, dy: -screen.frame.minY)
        clip.masksToBounds = true
        clip.cornerRadius = pictures[current].cornerRadius
        clip.cornerCurve = .continuous
        let layers = pictures.enumerated().map { index, picture in layer(picture, in: zone, shiftedBy: CGFloat(index - current) * zone.width) }
        layers.forEach { clip.addSublayer($0) }
        root.addSublayer(clip)
        let slide = Running(clip: clip, zone: zone, forward: true, completion: {})
        slide.started = true
        running = slide
        scrubbing = Scrubbing(slide: slide, layers: layers, current: current, width: zone.width)
        return true
    }

    func scrub(to offset: CGFloat) {
        guard let s = scrubbing else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for (index, layer) in s.layers.enumerated() {
            layer.position.x = CGFloat(index - s.current) * s.width + layer.bounds.width / 2 + offset
        }
        CATransaction.commit()
    }

    func catchScrub() -> CGFloat? {
        guard scrubbing == nil, let slide = running, let swipe = slide.swipe, let first = swipe.layers.first else { return nil }
        // Whatever was going to happen at the end of the glide is called off, the pictures stay where they are.
        slide.generation += 1
        if slide.fading {
            slide.fading = false
            slide.clip.removeAnimation(forKey: "fade")
        }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let from = (first.presentation() ?? first).position.x - first.bounds.width / 2
        for layer in swipe.layers {
            layer.position = (layer.presentation() ?? layer).position
            layer.removeAnimation(forKey: "slide")
        }
        CATransaction.commit()
        scrubbing = Scrubbing(slide: slide, layers: swipe.layers, current: swipe.current, width: swipe.width)
        return from + CGFloat(swipe.current) * swipe.width   // the first picture rests `current` windows to the left of the one in front
    }

    func endScrub(shift: Int, covered: @escaping (_ done: @escaping () -> Void) -> Void, completion: @escaping () -> Void) {
        guard let s = scrubbing else {
            covered { }
            return completion()
        }
        scrubbing = nil
        s.slide.swipe = (s.layers, s.current + shift, s.width)
        s.slide.completion = completion
        s.slide.items = s.layers.enumerated().map { index, layer in
            .init(layer: layer, restLeft: CGFloat(index - s.current - shift) * s.width)
        }
        go(s.slide, covered: covered)
    }

    func slide(leaving: WindowPicture, entering: WindowPicture, in zone: CGRect, forward: Bool,
               covered: @escaping (_ done: @escaping () -> Void) -> Void, completion: @escaping () -> Void) {
        let cocoaZone = screens.flip(zone)
        // The screen that shows most of the zone: a scrolled layout can leave the middle of a zone beyond the screen's edge.
        guard let screen = NSScreen.screens.max(by: { overlap($0.frame, cocoaZone) < overlap($1.frame, cocoaZone) }),
              overlap(screen.frame, cocoaZone) > 0, let root = panels.panel(for: screen).contentView?.layer else {
            // Nothing of the zone is in view: no slide, but the real window still changes.
            covered { }
            return completion()
        }

        // Everything of the slide lives in one layer: the zone, cut off at its edge.
        let clip = CALayer()
        clip.frame = cocoaZone.offsetBy(dx: -screen.frame.minX, dy: -screen.frame.minY)
        clip.masksToBounds = true
        clip.cornerRadius = leaving.cornerRadius
        clip.cornerCurve = .continuous
        let side: CGFloat = forward ? 1 : -1
        let out = layer(leaving, in: zone, shiftedBy: 0)
        let into = layer(entering, in: zone, shiftedBy: side * zone.width)
        clip.addSublayer(out)
        clip.addSublayer(into)
        root.addSublayer(clip)
        let slide = Running(clip: clip, zone: zone, forward: forward, completion: completion)
        slide.items = [.init(layer: out, restLeft: -side * zone.width), .init(layer: into, restLeft: 0)]
        running = slide

        // A few frames for the window server to put the pictures on screen, then the real windows may change and
        // the slide begins.
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.settle) { [weak self] in
            slide.started = true
            self?.go(slide, covered: covered)
        }
    }

    func extend(entering: WindowPicture, forward: Bool, covered: @escaping (_ done: @escaping () -> Void) -> Void) -> Bool {
        guard let slide = running, slide.started, slide.forward == forward, let last = slide.items.last else { return false }
        if slide.fading {
            // The pictures are giving way to the real windows: they come back, and the slide goes on.
            slide.fading = false
            slide.clip.removeAnimation(forKey: "fade")
        }
        let side: CGFloat = forward ? 1 : -1
        // Everything moves on by one more zone, from where it is now; the new picture waits beside the last one.
        let lastLeft = (last.layer.presentation()?.position.x ?? last.layer.position.x) - last.layer.bounds.width / 2
        for index in slide.items.indices {
            let layer = slide.items[index].layer
            let now = layer.presentation()?.position.x ?? layer.position.x
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            layer.position.x = now
            CATransaction.commit()
            slide.items[index].restLeft -= side * slide.zone.width
        }
        let picture = layer(entering, in: slide.zone, shiftedBy: 0)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        picture.position.x = lastLeft + side * slide.zone.width + picture.bounds.width / 2
        slide.clip.addSublayer(picture)
        CATransaction.commit()
        slide.items.append(.init(layer: picture, restLeft: 0))
        go(slide, covered: covered)
        return true
    }

    /// Lets the real window change (the pictures cover the zone) and moves every picture to its resting place; the pictures give
    /// way to the real windows once the slide is nearly at rest and the real window has really arrived: an app that is slow to come
    /// forward must not show the old window in the middle of the slide.
    private func go(_ slide: Running, covered: @escaping (_ done: @escaping () -> Void) -> Void) {
        slide.generation += 1
        let generation = slide.generation
        var atRest = false, windowReady = false
        func handOverWhenBoth() {
            guard atRest, windowReady, slide.generation == generation, !slide.fading else { return }
            slide.fading = true
            fadeOut(slide.clip) { [weak self] in
                // Carried on meanwhile: the slide is not over.
                guard slide.generation == generation, slide.fading else { return }
                slide.clip.removeFromSuperlayer()
                if self?.running === slide { self?.running = nil }
                slide.completion()
            }
        }
        covered {
            // A frame or two for the window server to draw it.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) { windowReady = true; handOverWhenBoth() }
        }
        let duration = slide.items.map { move($0.layer, toLeft: $0.restLeft) }.max() ?? 0
        DispatchQueue.main.asyncAfter(deadline: .now() + duration * Self.handOver) { atRest = true; handOverWhenBoth() }
    }

    private func overlap(_ a: CGRect, _ b: CGRect) -> CGFloat {
        let r = a.intersection(b)
        return r.isNull ? 0 : r.width * r.height
    }

    /// The picture's own place in the zone: at the zone's corner, where windows are put, keeping its own size. Where the photograph
    /// says the window was is not used: the list it comes from is kept for a few seconds and does not know that the window has
    /// been moved since (by a scroll, say).
    private func layer(_ picture: WindowPicture, in zone: CGRect, shiftedBy dx: CGFloat) -> CALayer {
        let layer = WindowPictureLayer(picture)
        let x = dx
        let y = zone.height - picture.frame.height   // the layer's origin is bottom-left
        layer.frame = CGRect(x: x, y: y, width: picture.frame.width, height: picture.frame.height)
        return layer
    }

    /// Starts the spring of a layer from where it is (on screen) to the resting place with its left edge at `left`; returns how long
    /// the spring takes to settle.
    private func move(_ layer: CALayer, toLeft left: CGFloat) -> CFTimeInterval {
        layer.removeAnimation(forKey: "slide")
        let animation = CASpringAnimation(keyPath: "position.x")
        animation.mass = 1
        animation.stiffness = Self.stiffness
        animation.damping = Self.damping
        animation.fromValue = layer.position.x
        animation.toValue = left + layer.bounds.width / 2
        animation.duration = animation.settlingDuration
        animation.fillMode = .forwards
        animation.isRemovedOnCompletion = false
        layer.add(animation, forKey: "slide")
        return animation.duration
    }

    private func fadeOut(_ clip: CALayer, _ completion: @escaping () -> Void) {
        CATransaction.begin()
        CATransaction.setCompletionBlock(completion)
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 1
        fade.toValue = 0
        fade.duration = Self.fade
        fade.fillMode = .forwards
        fade.isRemovedOnCompletion = false
        clip.add(fade, forKey: "fade")
        CATransaction.commit()
    }
}
