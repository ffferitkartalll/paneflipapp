import CoreGraphics

/// Records what the scroll stage is asked to do; the test decides when the pictures are "on screen".
final class FakeScrollStage: ScrollStaging {
    private(set) var begun: [[ScrollPicture]] = []
    private(set) var updates: [[ScrollPicture]] = []
    private(set) var shifts: [CGFloat] = []
    private(set) var finished = 0
    var coversAtOnce = true
    private var covers: [() -> Void] = []

    func begin(pictures: [ScrollPicture], over visible: CGRect, covered: @escaping () -> Void) {
        begun.append(pictures)
        if coversAtOnce { covered() } else { covers.append(covered) }
    }

    func update(pictures: [ScrollPicture]) { updates.append(pictures) }

    func follow(shift: CGFloat) { shifts.append(shift) }

    func finish(completion: @escaping () -> Void) { finished += 1; completion() }

    /// How many times the pictures were kept after all.
    private(set) var kept = 0
    func keep() { kept += 1 }

    /// The pictures are on screen now.
    func cover() { covers.forEach { $0() }; covers = [] }
}
