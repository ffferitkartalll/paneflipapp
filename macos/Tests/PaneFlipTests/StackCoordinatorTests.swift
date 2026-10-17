import XCTest
import CoreGraphics
import PaneFlipCore

final class StackCoordinatorTests: XCTestCase {
    private var windows: FakeWindowSystem!
    private var memory: StackMemory!
    private var coordinator: StackCoordinator!

    override func setUp() {
        windows = FakeWindowSystem()
        memory = StackMemory(store: MemoryDocumentStore())
        coordinator = StackCoordinator(windows: windows, memory: memory,
                                       settings: AppSettings(storage: StubSettingsStorage()), apps: FakeApps())
    }

    /// Two neighbours widened by 4 pt overlap at the edge. Which one wins must not depend on set order.
    func testDropOnTheEdgeBetweenZonesGoesToTheZoneThatHoldsThePoint() {
        for _ in 0..<30 {   // fresh ids every time, so the set order differs
            let left = UUID(), right = UUID()
            coordinator.apply(zones: [left: CGRect(x: 0, y: 0, width: 100, height: 100),
                                      right: CGRect(x: 100, y: 0, width: 100, height: 100)])
            XCTAssertEqual(coordinator.zoneID(at: CGPoint(x: 101, y: 50)), right)
            XCTAssertEqual(coordinator.zoneID(at: CGPoint(x: 99, y: 50)), left)
        }
    }

    func testPointJustOutsideAZoneStillCountsThroughTheMargin() {
        let zone = UUID()
        coordinator.apply(zones: [zone: CGRect(x: 0, y: 0, width: 100, height: 100)])
        XCTAssertEqual(coordinator.zoneID(at: CGPoint(x: 102, y: 50)), zone)
        XCTAssertNil(coordinator.zoneID(at: CGPoint(x: 120, y: 50)))
    }

    func testSnapRemembersTheWindowAndUnsnapForgetsIt() {
        let zone = UUID()
        coordinator.apply(zones: [zone: CGRect(x: 0, y: 0, width: 100, height: 100)])
        coordinator.snap(.fake(1), into: zone)
        XCTAssertEqual(memory.records.count, 1)
        XCTAssertEqual(coordinator.stacks[zone]?.tabs.map(\.id), [1])

        coordinator.unsnap(window: 1)
        XCTAssertTrue(memory.records.isEmpty)
        XCTAssertEqual(coordinator.stacks[zone]?.tabs.count, 0)
    }

    func testLeavingTheStackRaisesNoOtherWindow() {
        let zone = UUID()
        coordinator.apply(zones: [zone: CGRect(x: 0, y: 0, width: 100, height: 100)])
        coordinator.snap(.fake(1), into: zone)
        coordinator.snap(.fake(2), into: zone)
        let raisedBefore = windows.raised.count

        coordinator.release(window: 2)

        XCTAssertEqual(windows.raised.count, raisedBefore)
        XCTAssertEqual(coordinator.stacks[zone]?.tabs.map(\.id), [1])
    }

    func testAPillClickSlidesTheChosenWindowAndTheRealOneComesToTheFront() {
        let snapshots = FakeWindowSnapshots(), stage = FakeSlideStage()
        snapshots.images = [1: FakeWindowSnapshots.picture(), 2: FakeWindowSnapshots.picture()]
        coordinator.carousel = ZoneCarousel(snapshots: snapshots, stage: stage, reduceMotion: { false }, background: { $0() })
        let zone = UUID()
        coordinator.apply(zones: [zone: CGRect(x: 0, y: 0, width: 100, height: 100)])
        coordinator.snap(.fake(1), into: zone)
        coordinator.snap(.fake(2), into: zone)
        let stack = coordinator.stacks[zone]!
        XCTAssertEqual(stack.activeID, 2)

        coordinator.slideSelect(1, in: stack)

        XCTAssertEqual(stage.slides.count, 1)
        XCTAssertEqual(stage.slides.first?.forward, false, "window 1 comes before window 2 in the pill, so it comes in from the left")
        XCTAssertEqual(stack.activeID, 1)
        XCTAssertEqual(windows.raised.last, 1)
        XCTAssertTrue(coordinator.isSliding)

        coordinator.slideSelect(2, in: stack)
        XCTAssertEqual(stack.activeID, 1, "a click during the slide is ignored")
        stage.end()
        XCTAssertFalse(coordinator.isSliding)
    }

    func testWithoutACarouselThePillClickJustSelects() {
        let zone = UUID()
        coordinator.apply(zones: [zone: CGRect(x: 0, y: 0, width: 100, height: 100)])
        coordinator.snap(.fake(1), into: zone)
        coordinator.snap(.fake(2), into: zone)
        coordinator.slideSelect(1, in: coordinator.stacks[zone]!)
        XCTAssertEqual(coordinator.stacks[zone]?.activeID, 1)
    }

    func testThePillMovesAtTheClickWhileTheRealWindowWaitsForThePictures() {
        let snapshots = FakeWindowSnapshots(), stage = FakeSlideStage()
        snapshots.images = [1: FakeWindowSnapshots.picture(), 2: FakeWindowSnapshots.picture()]
        stage.coversAtOnce = false   // the pictures are not on screen yet
        coordinator.carousel = ZoneCarousel(snapshots: snapshots, stage: stage, reduceMotion: { false }, background: { $0() })
        let zone = UUID()
        coordinator.apply(zones: [zone: CGRect(x: 0, y: 0, width: 100, height: 100)])
        coordinator.snap(.fake(1), into: zone)
        coordinator.snap(.fake(2), into: zone)
        let stack = coordinator.stacks[zone]!

        coordinator.slideSelect(1, in: stack)
        XCTAssertEqual(stack.activeID, 1, "the pill follows at once")
        XCTAssertEqual(windows.raised.last, 2, "while the real window waits for the pictures")

        stage.cover()
        XCTAssertEqual(windows.raised.last, 1)
    }
}
