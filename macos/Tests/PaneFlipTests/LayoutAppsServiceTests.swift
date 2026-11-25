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
                                    glyphImages: GlyphImages(brands: NoBrands()), settings: settings, windows: windows)
    }

    func testOpeningStartsTheAppsThatAreNotRunningAndReopensThoseWithoutAWindow() {
        let apps = FakeApps()
        apps.apps = [AppInfo(pid: 1, bundleID: "com.example.one", name: "One"), AppInfo(pid: 2, bundleID: "com.example.two", name: "Two"),
                     AppInfo(pid: 3, bundleID: "com.example.three", name: "Three")]
        windows.showingPIDs = [1]   // "one" has its window; "two" was closed with Cmd+W; "four" was quit with Cmd+Q
        let coordinator = StackCoordinator(windows: windows, memory: memory, settings: settings, apps: apps)
        let opener = LayoutAppsService(memory: memory, coordinator: coordinator, apps: apps, refresher: refresher,
                                       glyphImages: GlyphImages(brands: NoBrands()), settings: settings, windows: windows)
        settings.values.ignoredApps = ["com.example.three"]

        opener.open(apps: ["com.example.one", "com.example.two", "com.example.two", "com.example.three", "com.example.four"])

        XCTAssertEqual(Set(apps.launched), ["com.example.two", "com.example.four"], "not the one with a window, not the ignored one")
        XCTAssertEqual(apps.launched.count, 2, "each once")
    }

    func testOnlyTickedAppsThatStillHaveAZoneAreStarted() {
        let layout = NamedLayout(name: "x", root: .leaf(zone))
        memory.remember(zoneID: zone, bundleID: "com.example.one", title: "")
        memory.remember(zoneID: zone, bundleID: "com.example.two", title: "")
        service.setStart(true, app: "com.example.one", inZones: layout.strip.zoneIDs)
        service.setStart(true, app: "com.example.gone", inZones: layout.strip.zoneIDs)

        XCTAssertEqual(service.startApps(of: layout), ["com.example.one"])
    }

    func testTakingAnAppOutOfAZoneForgetsItAndTriggersAPlacement() {
        memory.remember(zoneID: zone, bundleID: "com.example.one", title: "")

        service.remove(app: "com.example.one", in: zone, inZones: [zone, other])

        XCTAssertTrue(memory.apps(inZones: [zone, other]).isEmpty)
        XCTAssertEqual(refresher.restores, 1)
    }

    func testSeveralWindowsOfAnAppAreOneEntryThatMovesAndGoesTogether() {
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
        XCTAssertEqual(memory.records.map(\.title), ["2", "1"])
    }

    func testAnotherSceneShowsAndChangesItsOwnAppsNotThoseOfTheSceneInUse() {
        let store = MemoryDocumentStore()
        let inUse = UUID(), other = UUID()
        let live = StackMemory(store: store, scene: inUse)
        live.remember(zoneID: zone, bundleID: "com.example.one", title: "")
        service = LayoutAppsService(memory: live, coordinator: StackCoordinator(windows: windows, memory: live, settings: settings, apps: FakeApps()), apps: FakeApps(),
                                    refresher: refresher, glyphImages: GlyphImages(brands: NoBrands()), settings: settings, windows: windows)
        service.scenes = (active: { inUse }, memory: { StackMemory(store: store, scene: $0) })

        let theOther = service.editing(scene: other)
        XCTAssertTrue(theOther.entries(inZones: [zone]).isEmpty, "the same layout in another scene has no apps")

        StackMemory(store: store, scene: other).remember(zoneID: zone, bundleID: "com.example.two", title: "")
        theOther.clear(zones: [zone])
        XCTAssertEqual(live.records.map(\.bundleID), ["com.example.one"], "the scene in use is left alone")
    }
}
