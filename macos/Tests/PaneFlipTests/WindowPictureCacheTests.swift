import XCTest
import CoreGraphics

final class WindowPictureCacheTests: XCTestCase {
    private var time: TimeInterval = 0
    private func cache(maxBytes: Int = 1 << 20) -> WindowPictureCache { WindowPictureCache(maxBytes: maxBytes, now: { self.time }) }
    private func picture(_ size: CGSize = CGSize(width: 100, height: 100)) -> WindowPicture {
        let base = FakeWindowSnapshots.picture()
        return WindowPicture(image: base.image, frame: CGRect(origin: .zero, size: size), cornerRadius: 0)
    }

    func testAPictureIsGivenBackUntilItIsTooOld() {
        let c = cache()
        c.store(picture(), of: 1)
        XCTAssertNotNil(c.picture(of: 1, zoneSize: nil))
        time = 61
        XCTAssertNil(c.picture(of: 1, zoneSize: nil))
        XCTAssertEqual(c.count, 0)
    }

    func testAShorterAgeIsHonoured() {
        let c = cache()
        c.store(picture(), of: 1)
        time = 2
        XCTAssertNil(c.picture(of: 1, zoneSize: nil, maxAge: 1))
    }

    func testAPictureOfAnotherSizeThanTheZoneIsDropped() {
        let c = cache()
        c.store(picture(), of: 1)
        XCTAssertNotNil(c.picture(of: 1, zoneSize: CGSize(width: 101, height: 99)))
        XCTAssertNil(c.picture(of: 1, zoneSize: CGSize(width: 110, height: 100)))
        XCTAssertEqual(c.count, 0)
    }

    func testTheLeastRecentlyUsedGoesWhenTheBytesRunOut() {
        let one = FakeWindowSnapshots.picture().image.bytesPerRow * FakeWindowSnapshots.picture().image.height
        let c = cache(maxBytes: one * 2)
        c.store(picture(), of: 1); time = 1
        c.store(picture(), of: 2); time = 2
        _ = c.picture(of: 1, zoneSize: nil); time = 3   // 1 was used more recently than 2
        c.store(picture(), of: 3)
        XCTAssertNotNil(c.picture(of: 1, zoneSize: nil))
        XCTAssertNil(c.picture(of: 2, zoneSize: nil))
        XCTAssertNotNil(c.picture(of: 3, zoneSize: nil))
        XCTAssertEqual(c.totalBytes, one * 2)
    }

    func testPruneKeepsOnlyWhatIsHeld() {
        let c = cache()
        c.store(picture(), of: 1); c.store(picture(), of: 2)
        c.prune(keeping: [2])
        XCTAssertNil(c.picture(of: 1, zoneSize: nil))
        XCTAssertNotNil(c.picture(of: 2, zoneSize: nil))
        c.removeAll()
        XCTAssertEqual(c.totalBytes, 0)
    }
}
