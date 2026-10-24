import CoreGraphics

/// A floating zone's stage that notes what it was asked to show and lets the test decide when the picture "covers" the window.
final class FakeFloatStage: FloatStaging {
    private(set) var slides: [FloatSlide] = []
    private var starts: [() -> Void] = []

    func slide(_ slide: FloatSlide, started: @escaping () -> Void) {
        slides.append(slide)
        starts.append(started)
    }

    /// The picture is on screen: the real window that leaves may go.
    func start() { starts.forEach { $0() }; starts = [] }
}
