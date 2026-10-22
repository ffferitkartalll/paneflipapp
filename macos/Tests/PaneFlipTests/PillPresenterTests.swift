import AppKit
import XCTest
import PaneFlipCore

final class PillPresenterTests: XCTestCase {
    private final class NoBrands: BrandGlyphSource {
        var version = 0
        func glyph(forApp name: String) -> NSImage? { nil }
    }

    private var screens: FakeScreens!
    private var presenter: PillPresenter!
    private var coordinator: StackCoordinator!
    private var settings: AppSettings!
    private let zone = UUID()
    /// Windows of earlier tests stay in the app's list; only the ones this test made are looked at.
    private var earlier: Set<NSWindow> = []

    override func setUp() {
        earlier = Set(NSApp.windows)
        screens = FakeScreens()
        settings = AppSettings(storage: StubSettingsStorage())
        coordinator = StackCoordinator(windows: FakeWindowSystem(), memory: StackMemory(store: MemoryDocumentStore()),
                                           settings: settings, apps: FakeApps())
        coordinator.apply(zones: [zone: CGRect(x: 0, y: 0, width: 1000, height: 600)])
        coordinator.snap(.fake(1), into: zone)
        coordinator.snap(.fake(2), into: zone)
        presenter = PillPresenter(coordinator: coordinator, settings: settings, screens: screens,
                                  iconFont: IconFont(brands: NoBrands()), openOrdering: { _ in })
        screens.pointerAX = CGPoint(x: 500, y: 24 + PillMetrics.height / 2)   // on the pill: one menu bar below the top
    }

    private var panels: [PillPanel] { NSApp.windows.filter { !earlier.contains($0) }.compactMap { $0 as? PillPanel } }

    override func tearDown() {
        panels.forEach { $0.orderOut(nil) }
    }

    func testThePillTakesTheMouseOnlyWhileThePointerIsOnIt() {
        presenter.zonesDidChange()
        XCTAssertEqual(panels.first?.ignoresMouseEvents, false)
        screens.pointerAX = CGPoint(x: 500, y: 400)
        presenter.zonesDidChange()
        XCTAssertEqual(panels.first?.ignoresMouseEvents, true)
    }

    func testASingleWindowGetsNoPillUnlessTheSettingAsksForOne() {
        coordinator.unsnap(window: 2)
        presenter.zonesDidChange()
        XCTAssertEqual(panels.first?.ignoresMouseEvents, true)
        settings.values.pillForSingleWindow = true
        presenter.zonesDidChange()
        XCTAssertEqual(panels.first?.ignoresMouseEvents, false)
    }

    func testThePillStaysInViewWhenTheSettingAsksForIt() {
        screens.pointerAX = CGPoint(x: 500, y: 400)
        presenter.zonesDidChange()
        RunLoop.current.run(until: Date().addingTimeInterval(0.4))   // the fade takes 0.15 s
        XCTAssertEqual(panels.first?.alphaValue, 0)
        settings.values.pillAlwaysVisible = true
        presenter.zonesDidChange()
        RunLoop.current.run(until: Date().addingTimeInterval(0.4))
        XCTAssertEqual(panels.first?.alphaValue, 1)
        XCTAssertEqual(panels.first?.ignoresMouseEvents, true, "it does not take the mouse until the pointer is on it")
    }

    func testTheSettingTurnsThePillOffCompletely() {
        settings.values.pillAlwaysVisible = true
        settings.values.pillEnabled = false
        presenter.zonesDidChange()
        RunLoop.current.run(until: Date().addingTimeInterval(0.4))
        XCTAssertEqual(panels.first?.alphaValue, 0)
        XCTAssertEqual(panels.first?.ignoresMouseEvents, true)
        settings.values.pillEnabled = true
        presenter.zonesDidChange()
        RunLoop.current.run(until: Date().addingTimeInterval(0.4))
        XCTAssertEqual(panels.first?.alphaValue, 1)
    }

    func testThePillStaysAwayWhileMissionControlIsOpen() {
        screens.isMissionControlActive = true
        presenter.zonesDidChange()
        XCTAssertEqual(panels.first?.ignoresMouseEvents, true)
        screens.isMissionControlActive = false
        presenter.zonesDidChange()
        XCTAssertEqual(panels.first?.ignoresMouseEvents, false)
    }
}
