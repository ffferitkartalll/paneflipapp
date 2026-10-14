import XCTest
import CoreGraphics
import PaneFlipCore

final class LayoutAppsServiceTests: XCTestCase {
    private var memory: StackMemory!
    private var service: LayoutAppsService!
    private let zone = UUID(), other = UUID()

    private final class Refresher: ZoneRefreshing {
        var restores = 0
        func refreshZones() {}
        func restoreWindows() { restores += 1 }
    }
    private var refresher: Refresher!

    override func setUp() {
        memory = StackMemory(store: MemoryDocumentStore())
        refresher = Refresher()
        let apps = FakeApps()
        apps.apps = [AppInfo(pid: 1, bundleID: "com.example.one", name: "One")]
        let coordinator = StackCoordinator(windows: FakeWindowSystem(), memory: memory,
                                           settings: AppSettings(storage: StubSettingsStorage()), apps: apps)
        service = LayoutAppsService(memory: memory, coordinator: coordinator, apps: apps, refresher: refresher)
    }

    func testAnAddedAppIsListedInItsZoneAndTriggersAPlacement() {
        service.addApp(bundleID: "com.example.one", to: zone)
        let entries = service.entries(inZones: [zone, other])
        XCTAssertEqual(entries.map(\.name), ["One"])
        XCTAssertEqual(entries.first?.zoneID, zone)
        XCTAssertEqual(refresher.restores, 1)
    }

    func testMovingAndRemovingChangeTheLayoutsList() {
        service.addApp(bundleID: "com.example.one", to: zone)
        let slot = service.entries(inZones: [zone, other])[0].slot
        service.move(slot: slot, to: other, inZones: [zone, other])
        XCTAssertEqual(service.entries(inZones: [zone, other]).first?.zoneID, other)
        service.remove(slot: slot)
        XCTAssertTrue(service.entries(inZones: [zone, other]).isEmpty)
    }
}
