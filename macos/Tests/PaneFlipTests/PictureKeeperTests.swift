import XCTest
import CoreGraphics
import PaneFlipCore

final class PictureKeeperTests: XCTestCase {
    private var coordinator: StackCoordinator!
    private var inner: FakeWindowSnapshots!
    private var cache: WindowPictureCache!
    private var keeper: PictureKeeper!
    private var timers: [() -> Void] = []
    private var canCapture = true
    private var reduced = false
    private let zone = UUID(), other = UUID()

    override func setUp() {
        coordinator = StackCoordinator(windows: FakeWindowSystem(), memory: StackMemory(store: MemoryDocumentStore()),
                                       settings: AppSettings(storage: StubSettingsStorage()), apps: FakeApps())
        inner = FakeWindowSnapshots()
        cache = WindowPictureCache(now: { 0 })
        keeper = PictureKeeper(coordinator: coordinator, snapshots: inner, cache: cache, canCapture: { self.canCapture },
                               reduceMotion: { self.reduced }, now: { 0 }, after: { _, work in self.timers.append(work) })
        coordinator.apply(zones: [zone: CGRect(x: 0, y: 0, width: 100, height: 100), other: CGRect(x: 100, y: 0, width: 100, height: 100)])
        coordinator.snap(.fake(1), into: zone)
        coordinator.snap(.fake(2), into: zone)
        coordinator.snap(.fake(3), into: other)
        inner.images = [1: FakeWindowSnapshots.picture(), 2: FakeWindowSnapshots.picture(), 3: FakeWindowSnapshots.picture()]
        timers = []
    }

    private func fire() {
        let now = timers
        timers = []
        now.forEach { $0() }
    }

    func testAZoneWithSeveralWindowsIsPhotographedAndASingleOneIsNot() {
        keeper.motionEnded(); fire()
        XCTAssertNotNil(cache.picture(of: 1, zoneSize: nil))
        XCTAssertNil(cache.picture(of: 2, zoneSize: nil))   // in front: live, a slide takes it fresh
        XCTAssertNil(cache.picture(of: 3, zoneSize: nil))
    }

    func testNothingIsTakenWhileMovingWithReducedMotionOrWithoutPermission() {
        coordinator.isScrolling = true
        keeper.motionEnded(); fire()
        XCTAssertEqual(inner.requests, 0)
        coordinator.isScrolling = false
        canCapture = false
        keeper.motionEnded(); fire()
        XCTAssertEqual(inner.requests, 0)
        canCapture = true; reduced = true
        keeper.motionEnded(); fire()
        XCTAssertEqual(inner.requests, 0)
    }

    func testANewMotionCancelsTheSettlingThatWasWaiting() {
        keeper.motionEnded()
        keeper.motionEnded()
        let first = timers[0]
        first()
        XCTAssertEqual(inner.requests, 0)
        timers[1]()
        XCTAssertGreaterThan(inner.requests, 0)
    }

    func testOneCaptureIsInFlightAtATimeAndAFailedWindowIsNotRetriedAtOnce() {
        inner.answersAtOnce = false
        keeper.motionEnded(); fire()
        XCTAssertEqual(inner.requests, 1)
        inner.images = [:]
        inner.answer()   // window 1 has no picture: it failed a moment ago
        keeper.motionEnded(); fire()
        XCTAssertEqual(inner.requests, 1)
    }

    func testAWindowThatLeftTheFocusIsPhotographedAtRest() {
        cache.store(FakeWindowSnapshots.picture(), of: 1)   // young, but from before the user's last edits
        keeper.windowLeftFocus(1)
        XCTAssertNil(cache.picture(of: 1, zoneSize: nil))
        fire()
        XCTAssertEqual(inner.requests, 1)
        XCTAssertNotNil(cache.picture(of: 1, zoneSize: nil))
        timers = []
        keeper.windowLeftFocus(3)   // alone in its zone
        XCTAssertTrue(timers.isEmpty)
    }
}
