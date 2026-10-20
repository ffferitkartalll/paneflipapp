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
    private var settings: AppSettings!
    private let windows = FakeWindowSystem()

    override func setUp() {
        memory = StackMemory(store: MemoryDocumentStore())
        refresher = Refresher()
        let apps = FakeApps()
        apps.apps = [AppInfo(pid: 1, bundleID: "com.example.one", name: "One")]
        settings = AppSettings(storage: StubSettingsStorage())
        let coordinator = StackCoordinator(windows: windows, memory: memory, settings: settings, apps: apps)
        service = LayoutAppsService(memory: memory, coordinator: coordinator, apps: apps, refresher: refresher,
                                    iconFont: IconFont(brands: NoBrands()), settings: settings, windows: windows)
    }

    func testAnIgnoredAppCanNeitherBeAddedToAZoneNorOfferedForIt() {
        settings.values.ignoredApps = ["com.example.one"]

        service.addApp(bundleID: "com.example.one", to: zone)

        XCTAssertTrue(service.entries(inZones: [zone]).isEmpty)
        XCTAssertTrue(service.runningApps().isEmpty)
    }

    func testOpeningStartsTheAppsThatAreNotRunningAndReopensThoseWithoutAWindow() {
        let apps = FakeApps()
        apps.apps = [AppInfo(pid: 1, bundleID: "com.example.one", name: "One"), AppInfo(pid: 2, bundleID: "com.example.two", name: "Two"),
                     AppInfo(pid: 3, bundleID: "com.example.three", name: "Three")]
        windows.showingPIDs = [1]   // "one" has its window; "two" was closed with Cmd+W; "four" was quit with Cmd+Q
        let coordinator = StackCoordinator(windows: windows, memory: memory, settings: settings, apps: apps)
        let opener = LayoutAppsService(memory: memory, coordinator: coordinator, apps: apps, refresher: refresher,
                                       iconFont: IconFont(brands: NoBrands()), settings: settings, windows: windows)
        settings.values.ignoredApps = ["com.example.three"]

        opener.open(apps: ["com.example.one", "com.example.two", "com.example.two", "com.example.three", "com.example.four"])

        XCTAssertEqual(Set(apps.launched), ["com.example.two", "com.example.four"], "not the one with a window, not the ignored one")
        XCTAssertEqual(apps.launched.count, 2, "each once")
    }

    func testOnlyTickedAppsThatStillHaveAZoneAreStarted() {
        var layout = NamedLayout(name: "x", root: .leaf(zone))
        layout.startApps = ["com.example.one", "com.example.gone"]
        service.addApp(bundleID: "com.example.one", to: zone)
        service.addApp(bundleID: "com.example.two", to: zone)

        XCTAssertEqual(service.startApps(of: layout), ["com.example.one"])
        XCTAssertEqual(layout.startApps, ["com.example.one", "com.example.gone"], "the ticks themselves are left as the user made them")
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
