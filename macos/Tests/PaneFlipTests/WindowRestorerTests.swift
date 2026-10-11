import XCTest
import CoreGraphics
import PaneFlipCore

final class WindowRestorerTests: XCTestCase {
    private let zone = UUID()
    private var windows: FakeWindowSystem!
    private var screens: FakeScreens!
    private var apps: FakeApps!
    private var memory: StackMemory!
    private var settings: AppSettings!
    private var coordinator: StackCoordinator!
    private var restorer: WindowRestorer!

    override func setUp() {
        windows = FakeWindowSystem()
        screens = FakeScreens()
        apps = FakeApps()
        memory = StackMemory(store: MemoryDocumentStore())
        settings = AppSettings(storage: StubSettingsStorage())
        coordinator = StackCoordinator(windows: windows, memory: memory, settings: settings, apps: apps)
        restorer = WindowRestorer(windows: windows, apps: apps, memory: memory, coordinator: coordinator,
                                  availability: WindowAvailability(windows: windows, screens: screens), settings: settings)
        coordinator.apply(zones: [zone: CGRect(x: 0, y: 0, width: 800, height: 600)])
    }

    /// An app that is running with one visible window.
    private func launch(_ bundle: String, pid: pid_t, window id: CGWindowID) {
        apps.apps.append(AppInfo(pid: pid, bundleID: bundle, name: bundle))
        windows.windowsByPID[pid] = [.fake(id, pid: pid)]
        windows.all.insert(id)
        windows.onScreen.insert(id)
        screens.spacesByWindow[id] = [1]
    }

    func testWindowsComeBackInTheOrderTheUserArrangedThem() {
        memory.remember(zoneID: zone, bundleID: "app.a", title: "")
        memory.remember(zoneID: zone, bundleID: "app.b", title: "")
        launch("app.b", pid: 2, window: 20)   // started first, but arranged second
        launch("app.a", pid: 1, window: 10)

        restorer.restore()

        XCTAssertEqual(coordinator.stacks[zone]?.tabs.map(\.id), [10, 20])
    }

    func testThePillSelectsTheWindowThatIsInFront() {
        memory.remember(zoneID: zone, bundleID: "app.a", title: "")
        memory.remember(zoneID: zone, bundleID: "app.b", title: "")
        launch("app.a", pid: 1, window: 10)
        launch("app.b", pid: 2, window: 20)
        windows.frontToBack = [20, 10]   // b is on top, a is first in the arrangement

        restorer.restore()

        XCTAssertEqual(coordinator.stacks[zone]?.activeID, 20)
    }

    func testAWindowTheAppOnlyHidFromViewIsNotBroughtBack() {
        memory.remember(zoneID: zone, bundleID: "app.a", title: "")
        launch("app.a", pid: 1, window: 10)
        windows.onScreen.remove(10)   // hidden on close: still listed, on this desktop, not visible

        restorer.restore()

        XCTAssertEqual(coordinator.stacks[zone]?.tabs.count, 0)
        XCTAssertNil(memory.records[0].windowID)
    }

    func testWithoutStackingAZoneGetsOnlyOneWindow() {
        settings.values.stackingEnabled = false
        memory.remember(zoneID: zone, bundleID: "app.a", title: "")
        memory.remember(zoneID: zone, bundleID: "app.b", title: "")
        launch("app.a", pid: 1, window: 10)
        launch("app.b", pid: 2, window: 20)

        restorer.restore()

        XCTAssertEqual(coordinator.stacks[zone]?.tabs.map(\.id), [10])
    }

    func testNothingIsRestoredWithoutThePermission() {
        windows.isTrusted = false
        memory.remember(zoneID: zone, bundleID: "app.a", title: "")
        launch("app.a", pid: 1, window: 10)

        restorer.restore()

        XCTAssertEqual(coordinator.stacks[zone]?.tabs.count, 0)
    }
}
