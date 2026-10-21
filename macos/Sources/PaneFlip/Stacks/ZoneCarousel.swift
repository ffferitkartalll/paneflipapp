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
    /// The direction and zone of the slide that runs, and whether a picture for its extension is being taken.
    private var running: (forward: Bool, zone: CGRect)?
    private var extending = false
    /// The pictures are on the stage (the slide is not still waiting for its photographs).
    private var onStage = false
    /// The windows the pictures of a swipe the fingers led show, in order, from when it began until its glide has ended.
    private var swiped: [CGWindowID]?

    /// The pictures of a swipe still glide to their window: new fingers can take them over (`beginScrub`).
    var isSettlingSwipe: Bool { isSliding && swiped != nil }

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
        running = (forward, zone)
        slideCount += 1
        let mine = slideCount
        DispatchQueue.main.asyncAfter(deadline: .now() + giveUpAfter) { [weak self] in
            if let self, slideCount == mine { isSliding = false; running = nil; onStage = false }
        }
        snapshots.snapshots(of: [leaving, entering]) { [weak self] images in
            guard let self else { return }
            guard let out = images[leaving.id], let into = images[entering.id] else {
                isSliding = false
                running = nil
                return swap()
            }
            onStage = true
            stage.slide(leaving: out, entering: into, in: zone, forward: forward, covered: { [background] done in
                background {
                    swap()
                    DispatchQueue.main.async(execute: done)
                }
            }) { [weak self] in
                self?.isSliding = false
                self?.running = nil
                self?.onStage = false
            }
        }
    }

    /// Whether the slide that runs can be carried on to one more window: it goes the same way in the same zone, and no other
    /// extension is waiting for its picture.
    func canExtend(forward: Bool, in zone: CGRect) -> Bool {
        isSliding && onStage && !extending && running?.forward == forward && running?.zone == zone
    }

    /// Carries the running slide on to `entering` (the pictures are already there for the windows it passed; this one is
    /// photographed now). `swap` is as in `slide`. If the slide is over by the time the picture is there, or there is none, the
    /// window just comes forward.
    func extend(entering: WindowRef, forward: Bool, swap: @escaping () -> Void) {
        extending = true
        snapshots.snapshots(of: [entering]) { [weak self] images in
            guard let self else { return }
            extending = false
            guard let picture = images[entering.id],
                  stage.extend(entering: picture, forward: forward, covered: { [background] done in
                      background {
                          swap()
                          DispatchQueue.main.async(execute: done)
                      }
                  }) else { return background(swap) }
        }
    }

    // MARK: A slide the fingers lead

    /// The pictures of the zone's windows (`windows` in order, `current` the one in front) go on the stage, to follow the fingers
    /// (`scrub`). `ready` gets the windows that have a picture, in order, or nil when there is nothing to lead: motion is reduced, a
    /// slide runs, or the window in front could not be photographed; and, when the pictures were taken over from a swipe that still glided, how far they are from the window in front.
    /// From the call until `endScrub` (or a nil `ready`) the carousel counts as sliding, so nothing else slides. The pictures of an
    /// earlier swipe that still glide are taken over where they are, with no new photographs.
    func beginScrub(windows: [WindowRef], current: CGWindowID, in zone: CGRect, ready: @escaping ([CGWindowID]?, CGFloat?) -> Void) {
        if isSettlingSwipe, let shown = swiped, shown.contains(current), let carried = stage.catchScrub() { return ready(shown, carried) }
        guard !isSliding, !reduceMotion() else { return ready(nil, nil) }
        isSliding = true
        snapshots.snapshots(of: windows) { [weak self] images in
            guard let self else { return }
            let shown = windows.filter { images[$0.id] != nil }
            guard let index = shown.firstIndex(where: { $0.id == current }),
                  stage.beginScrub(pictures: shown.compactMap { images[$0.id] }, current: index, in: zone) else {
                isSliding = false
                return ready(nil, nil)
            }
            onStage = true
            swiped = shown.map(\.id)
            ready(swiped, nil)
        }
    }

    func scrub(to offset: CGFloat) { stage.scrub(to: offset) }

    /// The fingers lifted: the pictures glide on `shift` windows from the one in front. `swap` brings the real window forward, as in
    /// `slide` (it is not called for a shift of 0).
    func endScrub(shift: Int, swap: @escaping () -> Void) {
        stage.endScrub(shift: shift, covered: { [background] done in
            background {
                if shift != 0 { swap() }
                DispatchQueue.main.async(execute: done)
            }
        }) { [weak self] in
            self?.isSliding = false
            self?.running = nil
            self?.onStage = false
            self?.swiped = nil
        }
    }
}
