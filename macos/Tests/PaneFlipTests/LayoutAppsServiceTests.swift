import AppKit
import XCTest
import CoreGraphics
import PaneFlipCore

final class LayoutAppsServiceTests: XCTestCase {
    private var memory: StackMemory!
    private var service: LayoutAppsService!
    private let zone = UUID(), other = UUID()

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
        memory.remember(zoneID: zone, bundleID: "com.example.one", title: "")
        memory.remember(zoneID: zone, bundleID: "com.example.two", title: "")

        XCTAssertEqual(service.startApps(of: layout), ["com.example.one"])
        XCTAssertEqual(layout.startApps, ["com.example.one", "com.example.gone"], "the ticks themselves are left as the user made them")
    }

    func testTakingAnAppOutOfAZoneForgetsItAndTriggersAPlacement() {
        memory.remember(zoneID: zone, bundleID: "com.example.one", title: "")

        service.remove(app: "com.example.one", in: zone, inZones: [zone, other])

        XCTAssertTrue(memory.apps(inZones: [zone, other]).isEmpty)
        XCTAssertEqual(refresher.restores, 1)
    }
}
