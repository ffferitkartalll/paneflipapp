import XCTest
import CoreGraphics

/// The rules that decide a stacked window is gone. They were changed several times after real-world reports.
final class WindowAvailabilityTests: XCTestCase {
    private var windows: FakeWindowSystem!
    private var screens: FakeScreens!
    private var availability: WindowAvailability!
    private let window = WindowRef.fake(7)

    override func setUp() {
        windows = FakeWindowSystem()
        screens = FakeScreens()
        availability = WindowAvailability(windows: windows, screens: screens)
    }

    private var isGone: Bool { availability.isGone(window, in: availability.snapshot()) }

    func testWindowMissingFromTheSystemListIsGone() {
        XCTAssertTrue(isGone)
    }

    func testVisibleWindowIsNotGone() {
        windows.all = [7]; windows.onScreen = [7]; screens.spacesByWindow[7] = [1]
        XCTAssertFalse(isGone)
    }

    /// Apps that hide a window on close keep it in the list, on the current desktop, off screen.
    func testHiddenWindowOnTheCurrentDesktopIsGone() {
        windows.all = [7]; screens.spacesByWindow[7] = [1]
        XCTAssertTrue(isGone)
    }

    func testWindowOnAnotherDesktopIsNotGone() {
        windows.all = [7]; screens.spacesByWindow[7] = [2]
        XCTAssertFalse(isGone)
    }

    func testWindowThatBelongsToNoDesktopIsGone() {
        windows.all = [7]
        XCTAssertTrue(isGone)
    }
}
