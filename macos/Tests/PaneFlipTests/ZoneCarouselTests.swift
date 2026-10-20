import XCTest
import CoreGraphics

final class ZoneCarouselTests: XCTestCase {
    private var snapshots: FakeWindowSnapshots!
    private var stage: FakeSlideStage!
    private var reduceMotion = false
    private var carousel: ZoneCarousel!
    private let zone = CGRect(x: 100, y: 50, width: 400, height: 300)

    override func setUp() {
        snapshots = FakeWindowSnapshots()
        snapshots.images = [1: FakeWindowSnapshots.picture(), 2: FakeWindowSnapshots.picture()]
        stage = FakeSlideStage()
        carousel = ZoneCarousel(snapshots: snapshots, stage: stage, reduceMotion: { [unowned self] in reduceMotion }, background: { $0() })
    }

    private func slide(forward: Bool = true, swap: @escaping () -> Void = {}) {
        carousel.slide(leaving: .fake(1), entering: .fake(2), in: zone, forward: forward, swap: swap)
    }

    func testThePicturesSlideInTheZoneAndTheRealWindowsSwapUnderThem() {
        var swapped = 0
        slide(forward: false) { swapped += 1 }
        XCTAssertEqual(stage.slides.count, 1)
        XCTAssertEqual(stage.slides.first?.zone, zone)
        XCTAssertEqual(stage.slides.first?.forward, false)
        XCTAssertEqual(swapped, 1, "swapped as soon as the pictures cover the zone")
        XCTAssertTrue(carousel.isSliding)

        stage.end()
        XCTAssertFalse(carousel.isSliding)
    }

    func testTheRealWindowChangesOnlyOnceThePicturesAreOnScreen() {
        stage.coversAtOnce = false
        var swapped = false
        slide { swapped = true }
        XCTAssertEqual(stage.slides.count, 1)
        XCTAssertFalse(swapped, "the new window must not show before the pictures cover the zone")
        stage.cover()
        XCTAssertTrue(swapped)
    }

    func testPreparingWarmsUpTheSnapshots() {
        carousel.prepare()
        XCTAssertEqual(snapshots.prepared, 1)
    }

    func testTheSwapWaitsForThePictures() {
        snapshots.answersAtOnce = false
        var swapped = false
        slide { swapped = true }
        XCTAssertFalse(swapped)
        snapshots.answer()
        XCTAssertTrue(swapped)
    }

    func testWithoutAPictureTheWindowJustComesForward() {
        snapshots.images[2] = nil   // e.g. Screen Recording was switched off
        var swapped = false
        slide { swapped = true }
        XCTAssertTrue(swapped)
        XCTAssertTrue(stage.slides.isEmpty)
        XCTAssertFalse(carousel.isSliding)
    }

    func testReducedMotionSkipsTheSlide() {
        reduceMotion = true
        var swapped = false
        slide { swapped = true }
        XCTAssertTrue(swapped)
        XCTAssertTrue(stage.slides.isEmpty)
    }

    func testASlideWhoseCaptureNeverAnswersIsGivenUpOn() {
        carousel = ZoneCarousel(snapshots: snapshots, stage: stage, reduceMotion: { false }, background: { $0() }, giveUpAfter: 0.05)
        snapshots.answersAtOnce = false   // the capture never comes back
        slide()
        XCTAssertTrue(carousel.isSliding)
        let end = Date().addingTimeInterval(1)
        while carousel.isSliding && Date() < end { RunLoop.main.run(until: Date().addingTimeInterval(0.01)) }
        XCTAssertFalse(carousel.isSliding, "the pill must not stay dead")
    }

    func testASlideStartedWhileOneRunsIsIgnored() {
        slide()
        var second = false
        slide { second = true }
        XCTAssertFalse(second)
        XCTAssertEqual(stage.slides.count, 1)
    }

    func testARunningSlideIsCarriedOnToTheNextWindowInTheSameDirection() {
        snapshots.images[3] = FakeWindowSnapshots.picture()
        slide(forward: true)
        XCTAssertTrue(carousel.canExtend(forward: true, in: zone))
        XCTAssertFalse(carousel.canExtend(forward: false, in: zone), "the other way is not carried on")
        XCTAssertFalse(carousel.canExtend(forward: true, in: zone.offsetBy(dx: 500, dy: 0)), "nor in another zone")
        var swapped = 0
        carousel.extend(entering: .fake(3), forward: true) { swapped += 1 }
        XCTAssertEqual(stage.extensions, [true])
        XCTAssertEqual(swapped, 1, "the real window of the new picture comes forward under the pictures")
        XCTAssertEqual(stage.slides.count, 1, "no second slide is started")
    }

    func testAnExtensionWaitsForItsPictureAndIsAskedForOnlyOnce() {
        snapshots.images[3] = FakeWindowSnapshots.picture()
        slide()
        snapshots.answersAtOnce = false
        carousel.extend(entering: .fake(3), forward: true) {}
        XCTAssertFalse(carousel.canExtend(forward: true, in: zone), "one extension at a time")
        snapshots.answer()
        XCTAssertEqual(stage.extensions.count, 1)
        XCTAssertTrue(carousel.canExtend(forward: true, in: zone))
    }

    func testAnExtensionTooLateJustBringsTheWindowForward() {
        snapshots.images[3] = FakeWindowSnapshots.picture()
        slide()
        stage.canExtend = false   // the slide is giving way to the real windows
        var swapped = 0
        carousel.extend(entering: .fake(3), forward: true) { swapped += 1 }
        XCTAssertEqual(swapped, 1)
        XCTAssertTrue(stage.extensions.isEmpty)
    }
}
