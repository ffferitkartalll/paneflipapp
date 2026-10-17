import XCTest
import CoreGraphics

final class WindowGlideTests: XCTestCase {
    private let windows = FakeWindowSystem()
    private let target = CGRect(x: 100, y: 100, width: 400, height: 300)
    private var reduceMotion = false
    private var clock: TimeInterval = 0
    private var frames: [CGRect] = []

    /// A clock that advances 0.05 s on every look, and a window system that records every step.
    private func glide(duration: TimeInterval = 0.2, background: @escaping (@escaping () -> Void) -> Void = { $0() }) -> WindowGlide {
        WindowGlide(windows: windows, reduceMotion: { [unowned self] in reduceMotion }, background: background,
                    now: { [unowned self] in clock += 0.05; return clock }, duration: duration)
    }

    func testTheWindowTravelsInStepsAndLandsExactlyOnTheTarget() {
        windows.setFrame(CGRect(x: 0, y: 0, width: 200, height: 100), of: .fake(1))
        glide().glide(.fake(1), to: target)
        XCTAssertEqual(windows.frames[1], target)
        XCTAssertGreaterThan(windows.setCalls, 3, "more than the first and the last frame")
    }

    func testWithoutAStartFrameOrWithReducedMotionTheWindowJumps() {
        glide().glide(.fake(1), to: target)
        XCTAssertEqual(windows.setCalls, 1)
        windows.setFrame(.zero, of: .fake(2))
        let before = windows.setCalls
        reduceMotion = true
        glide().glide(.fake(2), to: target)
        XCTAssertEqual(windows.setCalls, before + 1)
        XCTAssertEqual(windows.frames[2], target)
    }

    func testACancelledGlideStopsWhereItIs() {
        windows.setFrame(.zero, of: .fake(1))
        var step: (() -> Void)?
        let glide = glide { step = $0 }
        glide.glide(.fake(1), to: target)
        glide.cancel(1)
        step?()
        XCTAssertNotEqual(windows.frames[1], target)
    }
}
