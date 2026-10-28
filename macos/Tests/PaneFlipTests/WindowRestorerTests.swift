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
        restorer = WindowRestorer(windows: windows, apps: apps, screens: screens, memory: memory, coordinator: coordinator,
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

    func testTheIslandSelectsTheWindowThatIsInFront() {
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

    func testNothingIsRestoredWithoutThePermission() {
        windows.isTrusted = false
        memory.remember(zoneID: zone, bundleID: "app.a", title: "")
        launch("app.a", pid: 1, window: 10)

        restorer.restore()

        XCTAssertEqual(coordinator.stacks[zone]?.tabs.count, 0)
    }

    // MARK: Which window of an app goes to a zone

    private let left = CGRect(x: 0, y: 0, width: 1000, height: 600)
    private let right = CGRect(x: 1000, y: 0, width: 1000, height: 600)

    private func display(_ name: String, _ area: CGRect) -> ScreenInfo {
        ScreenInfo(key: name, name: name, size: area.size, cocoaFrame: area, cocoaVisibleFrame: area, axVisible: area)
    }

    /// An app with two windows; the zone is the left display's left half.
    private func appWithTwoWindows(first: CGRect, second: CGRect) {
        screens.infos = [display("left", left), display("right", right)]
        coordinator.apply(zones: [zone: CGRect(x: 0, y: 0, width: 500, height: 600)])
        memory.remember(zoneID: zone, bundleID: "app.a", title: "remembered")
        apps.apps.append(AppInfo(pid: 1, bundleID: "app.a", name: "app.a"))
        windows.windowsByPID[1] = [.fake(10, pid: 1), .fake(11, pid: 1)]
        for id: CGWindowID in [10, 11] {
            windows.all.insert(id)
            windows.onScreen.insert(id)
            screens.spacesByWindow[id] = [1]
        }
        windows.setFrame(first, of: .fake(10, pid: 1))
        windows.setFrame(second, of: .fake(11, pid: 1))
    }

    func testAWindowOnAnotherDisplayIsNotPulledIntoTheZone() {
        appWithTwoWindows(first: right.insetBy(dx: 10, dy: 10), second: CGRect(x: 600, y: 50, width: 300, height: 300))

        restorer.restore()

        XCTAssertEqual(coordinator.stacks[zone]?.tabs.map(\.id), [11])
    }

    func testAWindowOnlyOnAnotherDisplayStaysWhereItIs() {
        appWithTwoWindows(first: right.insetBy(dx: 10, dy: 10), second: right.insetBy(dx: 20, dy: 20))

        restorer.restore()

        XCTAssertEqual(coordinator.stacks[zone]?.tabs.count, 0)
    }

    func testTheWindowInsideTheZoneTakesTheSlotAndTheOtherOneJoinsAfterIt() {
        appWithTwoWindows(first: CGRect(x: 600, y: 50, width: 300, height: 300), second: CGRect(x: 20, y: 20, width: 400, height: 300))

        restorer.restore()

        XCTAssertEqual(coordinator.stacks[zone]?.tabs.map(\.id), [11, 10])
    }

    /// An app with several windows open.
    private func launch(_ bundle: String, pid: pid_t, windows ids: [CGWindowID]) {
        apps.apps.append(AppInfo(pid: pid, bundleID: bundle, name: bundle))
        windowsByPIDFill(pid, ids)
    }

    private func windowsByPIDFill(_ pid: pid_t, _ ids: [CGWindowID]) {
        windows.windowsByPID[pid] = ids.map { .fake($0, pid: pid) }
        for id in ids {
            windows.all.insert(id)
            windows.onScreen.insert(id)
            screens.spacesByWindow[id] = [1]
        }
    }

    func testEveryWindowOfAnAppWithAZoneJoinsItNextToTheOthers() {
        memory.remember(zoneID: zone, bundleID: "app.a", title: "")
        memory.remember(zoneID: zone, bundleID: "app.b", title: "")
        launch("app.a", pid: 1, windows: [10, 11, 12])
        launch("app.b", pid: 2, windows: [20])

        restorer.restore()

        XCTAssertEqual(coordinator.stacks[zone]?.tabs.map(\.id), [10, 11, 12, 20])
    }

    func testAWindowTheUserPulledOutIsNotPulledBack() {
        memory.remember(zoneID: zone, bundleID: "app.a", title: "")
        launch("app.a", pid: 1, windows: [10, 11])
        restorer.restore()
        coordinator.unsnap(window: 11)

        restorer.restore()

        XCTAssertEqual(coordinator.stacks[zone]?.tabs.map(\.id), [10])
    }

    func testANewWindowOfTheFrontAppIsPickedUpOnTheNextLook() {
        memory.remember(zoneID: zone, bundleID: "app.a", title: "")
        launch("app.a", pid: 1, windows: [10])
        apps.frontmostPID = 1
        restorer.restoreFrontmost()
        XCTAssertEqual(coordinator.stacks[zone]?.tabs.map(\.id), [10])

        windowsByPIDFill(1, [10, 11])
        restorer.restoreFrontmost()

        XCTAssertEqual(coordinator.stacks[zone]?.tabs.map(\.id), [10, 11])
    }

    func testTwoWindowsOfOneAppOnTwoDisplaysEachComeBackToTheirOwnZone() {
        let near = zone, far = UUID()
        let nearRect = CGRect(x: 0, y: 0, width: 800, height: 600), farRect = CGRect(x: 1000, y: 0, width: 800, height: 600)
        func info(_ key: String, _ area: CGRect) -> ScreenInfo { ScreenInfo(key: key, name: key, size: area.size, cocoaFrame: area, cocoaVisibleFrame: area, axVisible: area) }
        screens.infos = [info("a|d1", nearRect), info("b|d1", farRect)]
        apps.apps.append(AppInfo(pid: 1, bundleID: "app.x", name: "x"))
        windows.windowsByPID[1] = [.fake(1, pid: 1), .fake(2, pid: 1)]
        for id: CGWindowID in [1, 2] { windows.all.insert(id); windows.onScreen.insert(id); screens.spacesByWindow[id] = [1] }
        coordinator.apply(zones: [near: nearRect, far: farRect])
        let slotNear = memory.remember(zoneID: near, bundleID: "app.x", title: "")
        let slotFar = memory.remember(zoneID: far, bundleID: "app.x", title: "")
        coordinator.attach(.fake(1, pid: 1), toSlot: slotNear, raise: false)
        coordinator.attach(.fake(2, pid: 1), toSlot: slotFar, raise: false)

        screens.infos = [info("a|d1", nearRect)]                       // the far display is unplugged
        coordinator.apply(zones: [near: nearRect])
        coordinator.displace(zones: [far], over: nearRect)
        screens.infos = [info("a|d1", nearRect), info("b|d1", farRect)]   // and plugged in again
        coordinator.apply(zones: [near: nearRect, far: farRect])
        coordinator.removeFromStack(window: 2)
        memory.returnHome(to: [far]).forEach { coordinator.removeFromStack(window: $0) }
        restorer.restore()

        XCTAssertEqual(coordinator.stacks[near]?.tabs.map(\.id), [1])
        XCTAssertEqual(coordinator.stacks[far]?.tabs.map(\.id), [2])
        XCTAssertEqual(windows.frames[2], farRect)
    }

    func testAWindowThatLeftWithItsDisplayComesBackEvenWhenTheAppDoesNotListItYet() {
        let near = zone, far = UUID()
        let nearRect = CGRect(x: 0, y: 0, width: 800, height: 600), farRect = CGRect(x: 1000, y: 0, width: 800, height: 600)
        func info(_ key: String, _ area: CGRect) -> ScreenInfo { ScreenInfo(key: key, name: key, size: area.size, cocoaFrame: area, cocoaVisibleFrame: area, axVisible: area) }
        screens.infos = [info("a|d1", nearRect), info("b|d1", farRect)]
        apps.apps.append(AppInfo(pid: 1, bundleID: "app.x", name: "x"))
        windows.windowsByPID[1] = [.fake(2, pid: 1)]
        windows.all.insert(2); windows.onScreen.insert(2); screens.spacesByWindow[2] = [1]
        coordinator.apply(zones: [near: nearRect, far: farRect])
        memory.remember(zoneID: near, bundleID: "app.x", title: "")
        let slotFar = memory.remember(zoneID: far, bundleID: "app.x", title: "")
        coordinator.attach(.fake(2, pid: 1), toSlot: slotFar, raise: false)
        coordinator.displace(zones: [far], over: nearRect)
        coordinator.apply(zones: [near: nearRect, far: farRect])
        memory.returnHome(to: [far]).forEach { coordinator.removeFromStack(window: $0) }
        windows.windowsByPID[1] = []      // the app does not list its windows now
        windows.onScreen.remove(2)

        restorer.restore()

        XCTAssertEqual(coordinator.stacks[far]?.tabs.map(\.id), [2])
    }

    func testAWindowThatLeftWithItsDisplayDoesNotJoinAZoneOfAnotherDisplayBeforeItsOwnZoneIsInView() {
        let near = zone, far = UUID()
        let nearRect = CGRect(x: 0, y: 0, width: 800, height: 600), farRect = CGRect(x: 1000, y: 0, width: 800, height: 600)
        func info(_ key: String, _ area: CGRect) -> ScreenInfo { ScreenInfo(key: key, name: key, size: area.size, cocoaFrame: area, cocoaVisibleFrame: area, axVisible: area) }
        screens.infos = [info("a|d1", nearRect)]
        apps.apps.append(AppInfo(pid: 1, bundleID: "app.x", name: "x"))
        windows.windowsByPID[1] = [.fake(2, pid: 1)]
        windows.all.insert(2); windows.onScreen.insert(2); screens.spacesByWindow[2] = [1]
        coordinator.apply(zones: [near: nearRect, far: farRect])
        memory.remember(zoneID: near, bundleID: "app.x", title: "")
        let slotFar = memory.remember(zoneID: far, bundleID: "app.x", title: "")
        coordinator.attach(.fake(2, pid: 1), toSlot: slotFar, raise: false)
        coordinator.displace(zones: [far], over: nearRect)
        coordinator.apply(zones: [near: nearRect])                 // the far display is back, its zones not yet in view
        memory.returnHome(to: [far]).forEach { coordinator.removeFromStack(window: $0) }

        restorer.restore()

        XCTAssertEqual(coordinator.stacks[near]?.tabs.count, 0, "it waits for its own zone")
        XCTAssertEqual(memory.records.count, 2)
        coordinator.apply(zones: [near: nearRect, far: farRect])   // the zones are in view
        restorer.restore()
        XCTAssertEqual(coordinator.stacks[far]?.tabs.map(\.id), [2])
    }
}
