import AppKit
import XCTest
import CoreGraphics
import PaneFlipCore

final class LayoutAppsServiceTests: XCTestCase {
    private var memory: StackMemory!
    private var service: LayoutAppsService!
    private let zone = UUID(), other = UUID()

    private final class NoBrands: BrandGlyphSource {
        var version = 0
        func glyph(forApp name: String) -> NSImage? { nil }
    }

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
        service = LayoutAppsService(memory: memory, coordinator: coordinator, apps: apps, refresher: refresher,
                                    iconFont: IconFont(brands: NoBrands()))
    }

    func testAnAddedAppIsListedInItsZoneAndTriggersAPlacement() {
        service.addApp(bundleID: "com.example.one", to: zone)
        let entries = service.entries(inZones: [zone, other])
        XCTAssertEqual(entries.map(\.name), ["One"])
        XCTAssertEqual(entries.first?.zoneID, zone)
        XCTAssertEqual(refresher.restores, 1)
    }

    func testAnAppIsListedOnceInAZone() {
        service.addApp(bundleID: "com.example.one", to: zone)
        service.addApp(bundleID: "com.example.one", to: zone)
        XCTAssertEqual(service.entries(inZones: [zone]).count, 1)
    }

    func testSeveralWindowsOfAnAppAreOneEntryThatMovesAndGoesTogether() {
        let memory = self.memory!
        let first = memory.remember(zoneID: zone, bundleID: "com.example.one", title: "1")
        memory.bind(slot: first, toWindow: 1, title: "1")
        let second = memory.remember(zoneID: zone, bundleID: "com.example.one", title: "2")
        memory.bind(slot: second, toWindow: 2, title: "2")
        var entries = service.entries(inZones: [zone, other])
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].windows.map(\.title), ["1", "2"])

        service.move(app: "com.example.one", from: zone, to: other, inZones: [zone, other])
        entries = service.entries(inZones: [zone, other])
        XCTAssertEqual(entries.map(\.zoneID), [other])

        service.remove(app: "com.example.one", in: other, inZones: [zone, other])
        XCTAssertTrue(service.entries(inZones: [zone, other]).isEmpty)
    }

    func testWindowsOfAnAppCanBeOrdered() {
        let a = memory.remember(zoneID: zone, bundleID: "com.example.one", title: "1")
        memory.bind(slot: a, toWindow: 1, title: "1")
        let b = memory.remember(zoneID: zone, bundleID: "com.example.one", title: "2")
        memory.bind(slot: b, toWindow: 2, title: "2")
        let second = service.entries(inZones: [zone])[0].windows[1].slot
        service.reorder(window: second, by: -1, inZones: [zone])
        // The windows are let go and put back by the restorer, which the fake refresher does not do.
        XCTAssertEqual(memory.records.map(\.title), ["2", "1"])
        XCTAssertEqual(refresher.restores, 1)
    }
}
