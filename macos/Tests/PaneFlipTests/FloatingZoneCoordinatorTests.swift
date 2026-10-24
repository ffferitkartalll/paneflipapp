import XCTest
import CoreGraphics
import PaneFlipCore

final class FloatingZoneCoordinatorTests: XCTestCase {
    private var windows: FakeWindowSystem!
    private var coordinator: StackCoordinator!
    private var memory: StackMemory!
    private let host = UUID(), floating = UUID()
    private let hostRect = CGRect(x: 0, y: 0, width: 1000, height: 800)
    private let floatRect = CGRect(x: 250, y: 200, width: 500, height: 400)
    private let away = CGRect(x: 999, y: 200, width: 500, height: 400)

    override func setUp() {
        windows = FakeWindowSystem()
        memory = StackMemory(store: MemoryDocumentStore())
        coordinator = StackCoordinator(windows: windows, memory: memory,
                                       settings: AppSettings(storage: StubSettingsStorage()), apps: FakeApps())
        coordinator.apply(plan: [host: PlannedZone(rect: hostRect, number: 1),
                                 floating: PlannedZone(rect: floatRect, number: 2, isFloating: true, awayFrame: away)])
        coordinator.snap(.fake(1), into: host)
        coordinator.snap(.fake(2), into: floating)
    }

    func testTheSmallerZoneUnderThePointerIsTheOneMeant() {
        XCTAssertEqual(coordinator.zoneID(at: CGPoint(x: 500, y: 400)), floating)
        XCTAssertEqual(coordinator.zoneID(at: CGPoint(x: 100, y: 100)), host)
    }

    func testTheWindowsGoBeyondTheRightEdgeWhenTheFocusLeavesAndComeBackWhenItReturns() {
        windows.focused = .fake(2)
        coordinator.followFocus()
        XCTAssertEqual(windows.frames[2], floatRect, "the focus is on it: it stays")

        windows.focused = .fake(1)
        coordinator.followFocus()
        XCTAssertEqual(windows.frames[2], away)
        XCTAssertEqual(windows.frames[1], hostRect, "the zone below is not touched")

        windows.focused = .fake(2)
        coordinator.followFocus()
        XCTAssertEqual(windows.frames[2], floatRect)
    }

    func testWithoutAPlaceBeyondTheEdgeTheWindowsStay() {
        coordinator.apply(plan: [host: PlannedZone(rect: hostRect, number: 1),
                                 floating: PlannedZone(rect: floatRect, number: 2, isFloating: true)])
        windows.focused = .fake(1)
        coordinator.followFocus()
        XCTAssertEqual(windows.frames[2], floatRect)
    }

    func testNothingMovesWhileTheFocusIsOnPaneFlipItself() {
        coordinator.holdsTheFocus = { true }
        windows.focused = nil
        coordinator.followFocus()
        XCTAssertEqual(windows.frames[2], floatRect)
    }

    func testAWindowThatCannotBeResizedStaysInTheMiddleAtItsOwnSize() {
        windows.fixedSize = [3]
        windows.setFrameDirectly(CGRect(x: 10, y: 10, width: 200, height: 100), of: 3)
        coordinator.snap(.fake(3), into: floating)
        let slot = coordinator.stacks[floating]!
        coordinator.select(3, in: slot)
        XCTAssertEqual(windows.frames[3], CGRect(x: 400, y: 350, width: 200, height: 100))

        windows.focused = .fake(1)
        coordinator.followFocus()
        XCTAssertEqual(windows.frames[3]?.size, CGSize(width: 200, height: 100))
        XCTAssertEqual(windows.frames[3]?.minX, away.minX)
        XCTAssertEqual(windows.frames[3]?.minY, 350, "at the height it had")
    }

    func testAWindowDroppedInTheZoneWhileItIsAwayBringsItBack() {
        windows.focused = .fake(1)
        coordinator.followFocus()
        coordinator.snap(.fake(4), into: floating)
        XCTAssertEqual(windows.frames[4], floatRect)
        XCTAssertEqual(windows.frames[2]?.minX, away.minX, "the zone does not stack: the window that was in view goes")
    }

    func testTheWindowLeavesAsAPictureThatCoversItAndTheRealWindowGoesOnlyOnceItDoes() {
        let snapshots = FakeWindowSnapshots(), stage = FakeFloatStage()
        snapshots.images[2] = FakeWindowSnapshots.picture()
        coordinator.snapshots = snapshots
        coordinator.floatStage = stage

        windows.focused = .fake(1)
        coordinator.followFocus()
        XCTAssertEqual(stage.slides.count, 1)
        XCTAssertEqual(stage.slides[0].to.minX, away.minX, "the picture glides to the place beyond the edge")
        XCTAssertEqual(windows.frames[2], floatRect, "the real window waits under the picture")

        stage.start()
        XCTAssertEqual(windows.frames[2]?.minX, away.minX)
    }

    func testAPictureThatCameTooLateIsNotShownWhenTheFocusAlreadyCameBack() {
        let snapshots = FakeWindowSnapshots(), stage = FakeFloatStage()
        snapshots.images[2] = FakeWindowSnapshots.picture()
        snapshots.answersAtOnce = false
        coordinator.snapshots = snapshots
        coordinator.floatStage = stage

        windows.focused = .fake(1)
        coordinator.followFocus()
        windows.focused = .fake(2)
        coordinator.followFocus()
        snapshots.answer()

        XCTAssertTrue(stage.slides.isEmpty)
        XCTAssertEqual(windows.frames[2], floatRect)
    }

    func testAWindowThatComesBackWithItsAppWaitsBeyondTheEdgeAtOnceWhenTheFocusIsElsewhere() {
        let stage = FakeFloatStage()
        coordinator.floatStage = stage
        let slot = memory.remember(zoneID: floating, bundleID: "", title: "")
        windows.focused = .fake(1)
        coordinator.removeFromStack(window: 2)
        coordinator.attach(.fake(5), toSlot: slot, raise: false)
        coordinator.followFocus()
        XCTAssertEqual(windows.frames[5]?.minX, away.minX)
        XCTAssertTrue(stage.slides.isEmpty, "nothing glides out")
    }

    func testAWindowThatComesBackWithTheFocusOnItStaysInView() {
        let slot = memory.remember(zoneID: floating, bundleID: "", title: "")
        windows.focused = .fake(5)
        coordinator.attach(.fake(5), toSlot: slot, raise: false)
        XCTAssertEqual(windows.frames[5], floatRect)
    }

    func testAFloatingZoneThatWaitsBeyondTheEdgeLeavesItsHostToThePointerButStillTakesADrop() {
        windows.focused = .fake(1)
        coordinator.followFocus()
        let middle = CGPoint(x: 500, y: 400)
        XCTAssertEqual(coordinator.zoneID(at: middle), host, "scrolling and the pill over the middle belong to the zone below")
        XCTAssertEqual(coordinator.zoneID(at: middle, forDrop: true), floating)
        XCTAssertFalse(coordinator.visibleStacks.contains { $0.id == floating })
        XCTAssertTrue(coordinator.dropStacks.contains { $0.id == floating })
    }

    func testTheWindowThatTakesTheFocusGlidesInAndTheOneItReplacesGlidesOut() {
        coordinator.snap(.fake(4), into: floating)   // 4 is in view, 2 waits beyond the edge
        windows.focused = .fake(4)
        coordinator.followFocus()
        XCTAssertEqual(windows.frames[4], floatRect)
        XCTAssertEqual(windows.frames[2]?.minX, away.minX)

        windows.focused = .fake(2)   // Dock or Cmd+Tab
        coordinator.followFocus()
        XCTAssertEqual(windows.frames[2], floatRect)
        XCTAssertEqual(windows.frames[4]?.minX, away.minX)
    }

    func testAFloatingZoneNeverStacks() {
        coordinator.snap(.fake(4), into: floating)
        XCTAssertFalse(coordinator.canScrubWindows(at: CGPoint(x: 500, y: 400)))
        XCTAssertFalse(coordinator.beginWindowScrub(in: coordinator.stacks[floating]!))
    }

    func testASwitchInsideTheZoneSlidesOneWindowOutAsAPictureAndTheOtherInAsItself() {
        coordinator.snap(.fake(4), into: floating)   // 4 is in view, 2 waits beyond the edge
        let snapshots = FakeWindowSnapshots(), stage = FakeFloatStage()
        snapshots.images[4] = FakeWindowSnapshots.picture()
        coordinator.snapshots = snapshots
        coordinator.floatStage = stage

        windows.focused = .fake(2)   // Dock or Cmd+Tab
        coordinator.followFocus()
        let slide = try! XCTUnwrap(stage.slides.first)
        XCTAssertEqual(slide.to.minX, away.minX)
        XCTAssertEqual(windows.frames[4], floatRect, "the window that goes stays until the picture covers it")
        XCTAssertEqual(windows.frames[2]?.minX, away.minX, "the window that comes waits until then")

        stage.start()
        XCTAssertEqual(windows.frames[4]?.minX, away.minX)
        XCTAssertEqual(windows.frames[2], floatRect, "the real window comes in itself")
    }

    func testThePictureAlwaysGoesOutFromBehindTheWindowThatHasTheFocus() {
        let snapshots = FakeWindowSnapshots(), stage = FakeFloatStage()
        snapshots.images[2] = FakeWindowSnapshots.picture()
        coordinator.snapshots = snapshots
        coordinator.floatStage = stage

        windows.focused = .fake(1)   // its zone lies under the floating zone: it is not seen behind it, and still it goes behind
        coordinator.followFocus()
        XCTAssertNotNil(stage.slides[0].raiseFocused)
    }
}
