import CoreGraphics

/// Records the slides it is asked to show and ends them when the test says so.
final class FakeSlideStage: SlideStaging {
    private(set) var slides: [(zone: CGRect, forward: Bool)] = []
    var coversAtOnce = true
    /// Whether a slide that runs can be carried on.
    var canExtend = true
    private(set) var extensions: [Bool] = []
    private var covers: [() -> Void] = []
    private var ends: [() -> Void] = []

    func slide(leaving: WindowPicture, entering: WindowPicture, in zone: CGRect, forward: Bool,
               covered: @escaping (_ done: @escaping () -> Void) -> Void, completion: @escaping () -> Void) {
        slides.append((zone, forward))
        ends.append(completion)
        if coversAtOnce { covered {} } else { covers.append { covered {} } }
    }

    func extend(entering: WindowPicture, forward: Bool, covered: @escaping (_ done: @escaping () -> Void) -> Void) -> Bool {
        guard canExtend, !ends.isEmpty else { return false }
        extensions.append(forward)
        covered {}
        return true
    }

    /// The panel is on screen now.
    func cover() { covers.forEach { $0() }; covers = [] }

    func end() { ends.forEach { $0() }; ends = [] }

    // The slide the fingers lead.
    var canScrub = true
    private(set) var scrubBegun: [(count: Int, current: Int)] = []
    private(set) var scrubOffsets: [CGFloat] = []
    private(set) var scrubEnded: [Int] = []

    func beginScrub(pictures: [WindowPicture], current: Int, in zone: CGRect) -> Bool {
        guard canScrub else { return false }
        scrubBegun.append((pictures.count, current))
        return true
    }

    func scrub(to offset: CGFloat) { scrubOffsets.append(offset) }

    /// How far the pictures of a gliding swipe are when new fingers take them over; nil: no swipe glides.
    var glidingAt: CGFloat?
    private(set) var catches = 0
    func catchScrub() -> CGFloat? {
        guard let glidingAt else { return nil }
        catches += 1
        return glidingAt
    }

    /// The glide after the fingers lift goes on until `endGlide` (new fingers can take the pictures over meanwhile).
    var holdsGlide = false
    private var glideEnd: (() -> Void)?
    func endGlide() { glideEnd?(); glideEnd = nil }

    func endScrub(shift: Int, covered: @escaping (_ done: @escaping () -> Void) -> Void, completion: @escaping () -> Void) {
        scrubEnded.append(shift)
        covered {}
        if holdsGlide { glideEnd = completion } else { completion() }
    }
}
