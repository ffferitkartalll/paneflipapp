import XCTest
import CoreGraphics
import PaneFlipCore

final class ZonePlacementTests: XCTestCase {
    private var windows: FakeWindowSystem!
    private var memory: StackMemory!
    private var coordinator: StackCoordinator!
    private var settings: AppSettings!
    private var picker: FakeZonePicker!
    private var placement: ZonePlacement!
    private var blocked = false
    private let a = UUID(), b = UUID(), c = UUID(), onAnotherDisplay = UUID(), beyondTheEdge = UUID()
    private let area = CGRect(x: 0, y: 0, width: 900, height: 600)

    override func setUp() {
        let repository = LayoutRepository(store: MemoryDocumentStore())
        windows = FakeWindowSystem()
        memory = StackMemory(store: MemoryDocumentStore())
        settings = AppSettings(storage: StubSettingsStorage())
        coordinator = StackCoordinator(windows: windows, memory: memory, settings: settings, apps: FakeApps())
        picker = FakeZonePicker()
        picker.row = [beyondTheEdge, a, b, c, onAnotherDisplay]   // the last lies on another display, which the picture of the first leads on to
        let screens = FakeScreens()
        placement = ZonePlacement(repository: repository, screens: screens, windows: windows, coordinator: coordinator, settings: settings, island: picker, isBlocked: { self.blocked })
        let layout = repository.addLayout(for: "main|d1")
        repository.setStrip(StripLayout(root: .split(id: UUID(), sideBySide: true, ratio: 0.33, first: .leaf(a), second: .split(id: UUID(), sideBySide: true, ratio: 0.5, first: .leaf(b), second: .leaf(c)))),
                            ofLayout: layout.id, key: "main|d1")
        repository.setDefaultZone(b, ofLayout: layout.id, key: "main|d1")
        screens.infos = [ScreenInfo(key: "main|d1", name: "main", size: area.size, cocoaFrame: area, cocoaVisibleFrame: area, axVisible: area)]
        coordinator.apply(plan: [beyondTheEdge: PlannedZone(rect: CGRect(x: -300, y: 0, width: 300, height: 600), frame: CGRect(x: -299, y: 0, width: 300, height: 600), isParked: true, number: 1, order: 0),
                                 a: PlannedZone(rect: CGRect(x: 0, y: 0, width: 300, height: 600), number: 1, order: 1),
                                 b: PlannedZone(rect: CGRect(x: 300, y: 0, width: 300, height: 600), number: 2, order: 2),
                                 c: PlannedZone(rect: CGRect(x: 600, y: 0, width: 300, height: 600), number: 3, order: 3),
                                 onAnotherDisplay: PlannedZone(rect: CGRect(x: 1000, y: 0, width: 300, height: 600), number: 1, order: 4)])
        windows.setFrame(CGRect(x: 100, y: 100, width: 200, height: 200), of: .fake(1))
        windows.focused = .fake(1)
    }

    func testAWindowInNoZoneStartsOnTheDefaultZoneAndGoesWhereTheArrowsLeadOnReturn() {
        placement.handle(.chord)
        XCTAssertTrue(picker.isOpen)
        XCTAssertEqual(picker.lit, b, "the default zone")
        placement.handle(.key(.move(.right)))
        XCTAssertEqual(picker.lit, c)
        XCTAssertNil(coordinator.stack(containing: 1), "nothing is done until Return")
        placement.handle(.key(.confirm))
        XCTAssertEqual(coordinator.stack(containing: 1)?.id, c)
        XCTAssertFalse(picker.isOpen)
        XCTAssertFalse(placement.isChoosing)
    }

    func testAWindowInAZoneStartsOnItsOwnZone() {
        coordinator.snap(.fake(1), into: a)
        placement.handle(.chord)
        XCTAssertEqual(picker.lit, a)
        placement.handle(.key(.move(.right)))
        placement.handle(.key(.confirm))
        XCTAssertEqual(coordinator.stack(containing: 1)?.id, b)
        XCTAssertEqual(memory.records.count, 1, "it moved, it was not added")
    }

    func testReturnOnTheOwnZoneChangesNothing() {
        coordinator.snap(.fake(1), into: a)
        placement.handle(.chord)
        placement.handle(.key(.confirm))
        XCTAssertEqual(coordinator.stack(containing: 1)?.id, a)
        XCTAssertEqual(memory.records.count, 1)
    }

    func testEscapeLetsTheWindowBe() {
        placement.handle(.chord)
        placement.handle(.key(.move(.left)))
        placement.handle(.key(.cancel))
        XCTAssertNil(coordinator.stack(containing: 1))
        XCTAssertFalse(picker.isOpen)
        XCTAssertFalse(placement.isChoosing)
    }

    func testTheLightStaysWhereItIsWhenNoZoneLiesThatWay() {
        placement.handle(.chord)
        placement.handle(.key(.move(.up)))
        XCTAssertEqual(picker.lit, b)
    }

    func testNothingStartsWhileOtherThingsHaveTheScreenOrWithNoWindowOrWhenOff() {
        blocked = true
        placement.handle(.chord)
        XCTAssertFalse(picker.isOpen)
        blocked = false
        windows.focused = nil
        placement.handle(.chord)
        XCTAssertFalse(picker.isOpen)
        windows.focused = .fake(1)
        settings.values.placementEnabled = false
        placement.handle(.chord)
        XCTAssertFalse(picker.isOpen)
    }

    func testAnotherChordWhileChoosingDoesNotStartOver() {
        placement.handle(.chord)
        placement.handle(.key(.move(.right)))
        placement.handle(.chord)
        XCTAssertEqual(picker.lit, c)
    }

    func testTheArrowKeysCanLeadToAZoneOfAnotherDisplay() {
        placement.handle(.chord)
        placement.handle(.key(.move(.right)))
        placement.handle(.key(.move(.right)))
        placement.handle(.key(.move(.right)))
        XCTAssertEqual(picker.lit, onAnotherDisplay)
        placement.handle(.key(.confirm))
        XCTAssertEqual(coordinator.stack(containing: 1)?.id, onAnotherDisplay)
    }

    func testBackspaceTakesAWindowOutOfItsZoneToTheMiddleOfItsScreenAtItsFormerSize() {
        settings.values.restoreSizeOnLeave = true
        coordinator.snap(.fake(1), into: a)
        placement.handle(.chord)
        placement.handle(.key(.remove))
        XCTAssertNil(coordinator.stack(containing: 1))
        XCTAssertTrue(memory.records.isEmpty)
        XCTAssertEqual(windows.frames[1], CGRect(x: 350, y: 200, width: 200, height: 200), "its size before the zone took it in, in the middle of the screen")
        XCTAssertFalse(placement.isChoosing)
        XCTAssertFalse(picker.isOpen)
    }

    func testWithoutTheSettingTheWindowKeepsTheSizeOfTheZone() {
        settings.values.restoreSizeOnLeave = false
        coordinator.snap(.fake(1), into: a)
        placement.handle(.chord)
        placement.handle(.key(.remove))
        XCTAssertEqual(windows.frames[1], CGRect(x: 300, y: 0, width: 300, height: 600))
    }

    func testBackspaceDoesNothingToAWindowInNoZone() {
        placement.handle(.chord)
        placement.handle(.key(.remove))
        XCTAssertTrue(placement.isChoosing, "the choice goes on")
        XCTAssertEqual(windows.frames[1], CGRect(x: 100, y: 100, width: 200, height: 200))
    }

    func testAWindowSentBeyondTheEdgeAsksTheLayoutToScrollThere() {
        var reached: UUID?
        coordinator.onReachBeyondTheEdge = { zone, _ in reached = zone; return true }
        placement.handle(.chord)
        placement.handle(.key(.move(.left)))
        placement.handle(.key(.move(.left)))
        XCTAssertEqual(picker.lit, beyondTheEdge)
        placement.handle(.key(.confirm))
        XCTAssertEqual(coordinator.stack(containing: 1)?.id, beyondTheEdge)
        XCTAssertEqual(reached, beyondTheEdge)
    }

    func testAWindowSentToAZoneOfTheScreenAsksTheLayoutToScrollBackFromBeyondTheEdge() {
        var asked: UUID?
        coordinator.onReachBeyondTheEdge = { zone, _ in asked = zone; return true }
        placement.handle(.chord)
        placement.handle(.key(.move(.right)))
        placement.handle(.key(.confirm))
        XCTAssertEqual(asked, c, "the layout decides whether it has to scroll back")
    }

    func testNothingScrollsWhenTheLayoutHasNoNeedTo() {
        coordinator.onReachBeyondTheEdge = { _, _ in false }
        placement.handle(.chord)
        placement.handle(.key(.move(.right)))
        placement.handle(.key(.confirm))
        XCTAssertEqual(coordinator.stack(containing: 1)?.id, c)
        XCTAssertNil(coordinator.focusedZoneID, "no focus was moved for a scroll that does not happen")
    }
}
