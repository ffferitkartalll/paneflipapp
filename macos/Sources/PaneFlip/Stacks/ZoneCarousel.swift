import CoreGraphics
import Foundation

/// The slide between two windows of a zone. Both are photographed, the pictures slide inside the zone (clipped at
/// its edge, over nothing else), and the real windows swap places underneath once the pictures cover the zone.
final class ZoneCarousel {
    private let snapshots: WindowSnapshotting
    private let stage: SlideStaging
    private let reduceMotion: () -> Bool
    /// Runs the window changes of a slide. Raising a window waits for the other app to answer, which can take a
    /// while; on the main thread it would hold up everything that moves with the slide, the pill included.
    private let background: (@escaping () -> Void) -> Void

    /// True from the click until the slide has ended; a click in between is ignored.
    private(set) var isSliding = false
    /// A slide that has not ended after this long is given up on, so a capture that never answers cannot leave the pill
    /// dead for the rest of the session.
    private let giveUpAfter: TimeInterval
    private var slideCount = 0

    init(snapshots: WindowSnapshotting, stage: SlideStaging, reduceMotion: @escaping () -> Bool,
         background: @escaping (@escaping () -> Void) -> Void, giveUpAfter: TimeInterval = 3) {
        self.giveUpAfter = giveUpAfter
        self.snapshots = snapshots
        self.stage = stage
        self.reduceMotion = reduceMotion
        self.background = background
    }

    /// A pill is about to be used: get the pictures' machinery warm.
    func prepare() { snapshots.prepare() }

    /// Slides `entering` in beside `leaving`. `swap` brings the real window forward (window calls only, it may run
    /// off the main thread): it runs once the pictures cover the zone, or at once when there is nothing to slide
    /// (no pictures, reduced motion).
    func slide(leaving: WindowRef, entering: WindowRef, in zone: CGRect, forward: Bool, swap: @escaping () -> Void) {
        guard !isSliding else { return }
        guard !reduceMotion() else { return swap() }
        isSliding = true
        slideCount += 1
        let mine = slideCount
        DispatchQueue.main.asyncAfter(deadline: .now() + giveUpAfter) { [weak self] in
            if let self, slideCount == mine { isSliding = false }
        }
        snapshots.snapshots(of: [leaving, entering]) { [weak self] images in
            guard let self else { return }
            guard let out = images[leaving.id], let into = images[entering.id] else {
                isSliding = false
                return swap()
            }
            stage.slide(leaving: out, entering: into, in: zone, forward: forward, covered: { [background] done in
                background {
                    swap()
                    DispatchQueue.main.async(execute: done)
                }
            }) { [weak self] in
                self?.isSliding = false
            }
        }
    }
}
