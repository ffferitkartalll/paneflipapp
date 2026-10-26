import XCTest
import CoreGraphics
import PaneFlipCore

final class ClosedWindowMonitorTests: XCTestCase {
    private var screens: FakeScreens!
    private var coordinator: StackCoordinator!
    private var monitor: ClosedWindowMonitor!
    private let zone = UUID()
    /// The list reads that were asked for and not yet run: a test decides when the system "answers".
    private var looks: [() -> Void] = []

    private func answer() {
        let now = looks
        looks = []
        now.forEach { $0() }
    }

    override func setUp() {
        let windows = FakeWindowSystem()
        screens = FakeScreens()
        coordinator = StackCoordinator(windows: windows, memory: StackMemory(store: MemoryDocumentStore()),
                                       settings: AppSettings(storage: StubSettingsStorage()), apps: FakeApps())
        monitor = ClosedWindowMonitor(coordinator: coordinator, availability: WindowAvailability(windows: windows, screens: screens),
                                      screens: screens, background: { self.looks.append($0) }, onMain: { $0() })
        coordinator.apply(zones: [zone: CGRect(x: 0, y: 0, width: 100, height: 100)])
        coordinator.snap(.fake(1), into: zone)   // not in the system list: it looks closed
    }

    private var held: Int { coordinator.stacks[zone]?.tabs.count ?? 0 }

    func testNothingIsReleasedWhileMissionControlIsOpen() {
        monitor.check()   // the first look records the desktops
        screens.isMissionControlActive = true
        monitor.check(); answer()
        monitor.check(); answer()
        XCTAssertEqual(held, 1)
    }

    func testTheFirstLookAfterMissionControlOnlyWaits() {
        monitor.check()
        screens.isMissionControlActive = true
        monitor.check(); answer()
        screens.isMissionControlActive = false
        monitor.check(); answer()
        XCTAssertEqual(held, 1)
        monitor.check(); answer()
        XCTAssertEqual(held, 0)
    }

    func testNoListIsReadWhileWindowsAreMovingAndOneAfter() {
        monitor.check()
        coordinator.isScrolling = true
        monitor.check()
        XCTAssertTrue(looks.isEmpty)
        coordinator.isScrolling = false
        monitor.check()
        XCTAssertEqual(looks.count, 1)
    }

    func testASlowListNeverStacksAnother() {
        monitor.check()
        monitor.check(); monitor.check()
        XCTAssertEqual(looks.count, 1)
    }

    func testAnAnswerThatArrivesDuringMotionIsDropped() {
        monitor.check()
        monitor.check()
        coordinator.isScrolling = true
        answer()
        XCTAssertEqual(held, 1)
    }

    func testAWindowReleasedMeanwhileIsNotReleasedAgain() {
        monitor.check()
        monitor.check()
        coordinator.release(window: 1)
        answer()
        XCTAssertEqual(held, 0)
    }
}
