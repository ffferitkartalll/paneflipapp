import XCTest
import CoreGraphics

final class CachedWindowSnapshotsTests: XCTestCase {
    private var inner: FakeWindowSnapshots!
    private var cache: WindowPictureCache!
    private var cached: CachedWindowSnapshots!
    private var turns: [() -> Void] = []
    private var time: TimeInterval = 0
    private var front: Set<CGWindowID> = []

    override func setUp() {
        inner = FakeWindowSnapshots()
        cache = WindowPictureCache(now: { self.time })
        cached = CachedWindowSnapshots(inner: inner, cache: cache, zoneSize: { _ in nil }, isFront: { self.front.contains($0) }, later: { self.turns.append($0) })
    }

    private func ask(_ ids: [CGWindowID]) -> [CGWindowID: WindowPicture]? {
        var result: [CGWindowID: WindowPicture]?
        cached.snapshots(of: ids.map { .fake($0) }) { result = $0 }
        return result
    }

    func testAllHitsMakeNoCaptureAndAnswerInTheNextTurn() {
        cache.store(FakeWindowSnapshots.picture(), of: 1)
        var answered: [CGWindowID: WindowPicture]?
        cached.snapshots(of: [.fake(1)]) { answered = $0 }
        XCTAssertNil(answered)
        XCTAssertEqual(inner.requests, 0)
        turns.forEach { $0() }
        XCTAssertEqual(answered?.keys.sorted(), [1])
    }

    func testOnlyTheMissesAreCapturedAndStored() {
        cache.store(FakeWindowSnapshots.picture(), of: 1)
        inner.images = [2: FakeWindowSnapshots.picture()]
        XCTAssertEqual(ask([1, 2])?.keys.sorted(), [1, 2])
        XCTAssertEqual(inner.requests, 1)
        XCTAssertNotNil(cache.picture(of: 2, zoneSize: nil))
    }

    func testAWindowThatCannotBePhotographedIsAbsent() {
        XCTAssertEqual(ask([3])?.count, 0)
    }

    func testAWindowInFrontIsLive() {
        cache.store(FakeWindowSnapshots.picture(), of: 1)
        front = [1]
        time = 5
        inner.images = [1: FakeWindowSnapshots.picture()]
        _ = ask([1])
        XCTAssertEqual(inner.requests, 0, "young enough: a swipe does not wait for a new picture")
        time = 11
        _ = ask([1])
        XCTAssertEqual(inner.requests, 1, "a picture of the window in front is good for a few seconds only")
    }
}
