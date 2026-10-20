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
}
