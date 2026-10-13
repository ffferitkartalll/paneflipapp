import XCTest
import CoreGraphics
import PaneFlipCore

final class ClosedWindowMonitorTests: XCTestCase {
    private var screens: FakeScreens!
    private var coordinator: StackCoordinator!
    private var monitor: ClosedWindowMonitor!
    private let zone = UUID()

    override func setUp() {
        let windows = FakeWindowSystem()
        screens = FakeScreens()
        coordinator = StackCoordinator(windows: windows, memory: StackMemory(store: MemoryDocumentStore()),
                                       settings: AppSettings(storage: StubSettingsStorage()), apps: FakeApps())
        monitor = ClosedWindowMonitor(coordinator: coordinator, availability: WindowAvailability(windows: windows, screens: screens),
                                      screens: screens)
        coordinator.apply(zones: [zone: CGRect(x: 0, y: 0, width: 100, height: 100)])
        coordinator.snap(.fake(1), into: zone)   // not in the system list: it looks closed
    }

    private var held: Int { coordinator.stacks[zone]?.tabs.count ?? 0 }

    func testNothingIsReleasedWhileMissionControlIsOpen() {
        screens.isMissionControlActive = true
        monitor.check()
        monitor.check()
        XCTAssertEqual(held, 1)
    }

    func testTheFirstLookAfterMissionControlOnlyWaits() {
        screens.isMissionControlActive = true
        monitor.check()
        screens.isMissionControlActive = false
        monitor.check()
        XCTAssertEqual(held, 1)
        monitor.check()
        XCTAssertEqual(held, 0)
    }
}
