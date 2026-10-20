import XCTest
import CoreGraphics
import PaneFlipCore

/// The planner, the scroller and the coordinator together, on a 1000 × 500 screen with a quarter-screen area on its right.
/// The windows: 1 (behind) and 3 (in front) in the screen's zone, 2 waiting in the area.
final class StripScrollingTests: XCTestCase {
    private let screenZone = UUID(), areaZone = UUID()
    private let key = "display|d1"
    private var repository: LayoutRepository!
    private var settings: AppSettings!
    private var viewport: StripViewport!
    private var planner: ZonePlanner!
    private var screens: FakeScreens!
    private var windows: FakeWindowSystem!
    private var coordinator: StackCoordinator!
    private var snapshots: FakeWindowSnapshots!
    private var stage: FakeScrollStage!
    private var reduceMotion = false
    private var clock = 0.0
    private var frames: [() -> Bool] = []

    private final class Refresher: ZoneRefreshing {
        var onRefresh: () -> Void = {}
        func refreshZones() { onRefresh() }
        func restoreWindows() {}
    }
    private var refresher: Refresher!

    private func screen(_ key: String, x: CGFloat = 0) -> ScreenInfo {
        let frame = CGRect(x: x, y: 0, width: 1000, height: 500)
        return ScreenInfo(key: key, name: "Screen", size: frame.size, cocoaFrame: frame, cocoaVisibleFrame: frame, axVisible: frame)
    }

    private func picture(_ frame: CGRect) -> WindowPicture {
        WindowPicture(image: FakeWindowSnapshots.picture().image, frame: frame, cornerRadius: 0)
    }

    override func setUp() {
        repository = LayoutRepository(store: MemoryDocumentStore())
        let layout = repository.addLayout(for: key)
        var strip = layout.strip
        strip.root = .leaf(screenZone)
        strip.trailing = Overflow(width: 0.25, root: .leaf(areaZone))
        repository.setStrip(strip, ofLayout: layout.id, key: key)
        var values = SettingsValues()
        values.gap = 0
        let storage = StubSettingsStorage()
        storage.saved = values
        settings = AppSettings(storage: storage)
        viewport = StripViewport()
        planner = ZonePlanner(layouts: repository, settings: settings, viewport: viewport)
        screens = FakeScreens()
        screens.infos = [screen(key)]
        screens.pointerCocoa = CGPoint(x: 500, y: 250)
        windows = FakeWindowSystem()
        coordinator = StackCoordinator(windows: windows, memory: StackMemory(store: MemoryDocumentStore()), settings: settings, apps: FakeApps())
        refresher = Refresher()
        refresher.onRefresh = { [unowned self] in coordinator.apply(plan: planner.plan(on: screens.infos)) }
        refresher.onRefresh()
        coordinator.snap(.fake(1), into: screenZone)
        coordinator.snap(.fake(3), into: screenZone)   // in front
        coordinator.stacks[areaZone]?.refs[2] = .fake(2)
        coordinator.stacks[areaZone]?.activeID = 2
        snapshots = FakeWindowSnapshots()
        snapshots.images = [3: picture(CGRect(x: 0, y: 0, width: 1000, height: 500)), 2: picture(CGRect(x: 999, y: 0, width: 250, height: 500))]
        stage = FakeScrollStage()
    }

    private func scroller(busy: Bool = false) -> StripScroller {
        StripScroller(screens: screens, planner: planner, viewport: viewport, settings: settings,
                      coordinator: coordinator, mover: WindowMover(windows: windows, background: { $0() }), snapshots: snapshots,
                      stage: stage, metronome: { [unowned self] tick in frames.append(tick) }, refresher: refresher,
                      reduceMotion: { [unowned self] in reduceMotion }, isBusy: { busy }, now: { [unowned self] in clock })
    }

    /// `count` frames of the display, `step` seconds apart.
    private func run(_ count: Int, step: Double = 1.0 / 120) {
        for _ in 0 ..< count {
            clock += step
            frames = frames.filter { $0() }
        }
    }

    /// Past the time the pictures take to go (asked after the windows have been put).
    private func settle() { RunLoop.current.run(until: Date().addingTimeInterval(0.15)) }

    func testAZoneBeyondTheEdgeWaitsWithOnePixelOnTheScreen() {
        let plan = planner.plan(on: screens.infos)
        XCTAssertEqual(plan[screenZone], PlannedZone(rect: CGRect(x: 0, y: 0, width: 1000, height: 500)))
        XCTAssertEqual(plan[areaZone]?.rect, CGRect(x: 1000, y: 0, width: 250, height: 500))
        XCTAssertEqual(plan[areaZone]?.frame, CGRect(x: 999, y: 0, width: 250, height: 500))
        XCTAssertEqual(plan[areaZone]?.isParked, true)
    }

    func testTheMarginKeepsTheZonesAwayFromTheEdgesOfTheScreen() {
        let bare = planner.plan(on: screens.infos)[screenZone]?.rect
        settings.values.edgeMargin = 20

        let rect = planner.plan(on: screens.infos)[screenZone]?.rect

        // The area lies on the right: the margin runs round the strip, so the zone keeps the right edge and has it on the others.
        XCTAssertEqual(rect, bare.map { CGRect(x: $0.minX + 20, y: $0.minY + 20, width: $0.width - 20, height: $0.height - 40) })
    }

    func testSwitchedOffTheAreaHasNoZoneAndNothingScrolls() {
        settings.values.overflowZonesEnabled = false
        let plan = planner.plan(on: screens.infos)
        XCTAssertNil(plan[areaZone])
        XCTAssertNotNil(plan[screenZone])
        let found = planner.strip(of: screens.infos[0], among: screens.infos)
        XCTAssertEqual(found?.0.range.lowerBound, found?.0.range.upperBound)
    }

    func testScrollingBringsTheAreaInAndTakesTheScreensZoneToTheLeft() {
        viewport.set(250, for: key)
        let plan = planner.plan(on: screens.infos)
        XCTAssertEqual(plan[areaZone]?.rect, CGRect(x: 750, y: 0, width: 250, height: 500))
        XCTAssertEqual(plan[areaZone]?.isParked, false)
        XCTAssertEqual(plan[screenZone]?.rect.minX, -250)
        XCTAssertEqual(plan[screenZone]?.isParked, false, "still partly on the screen")
    }

    func testADisplayOnTheRightSendsWaitingWindowsToTheLeftAndBothSidesTakeTheAreaAway() {
        screens.infos = [screen(key), screen("other|d1", x: 1000)]
        XCTAssertEqual(planner.plan(on: screens.infos)[areaZone]?.frame.maxX, 1)
        screens.infos = [screen(key), screen("other|d1", x: 1000), screen("third|d1", x: -1000)]
        XCTAssertNil(planner.plan(on: screens.infos)[areaZone], "no place to wait: the area does not exist on this screen")
    }

    func testAParkedZoneHasNoPillAndTakesNoDrops() {
        XCTAssertEqual(coordinator.visibleStacks.map(\.id), [screenZone], "the parked zone has no pill and takes no drops")
        XCTAssertNotNil(coordinator.zoneID(at: CGPoint(x: 500, y: 250)))
        XCTAssertNil(coordinator.zoneID(at: CGPoint(x: 1100, y: 250)))
    }

    func testThePicturesGlideWhileTheRealWindowsWaitAtTheEdge() {
        let scroller = scroller()
        scroller.start()
        XCTAssertTrue(scroller.scroll(toward: .right))
        XCTAssertEqual(stage.begun.count, 1)
        XCTAssertEqual(Set(stage.begun.first?.map(\.id) ?? []), [3, 2], "the front window of each zone, the one waiting beyond the edge too")
        XCTAssertEqual(stage.begun.first?.first { $0.id == 2 }?.picture.frame, CGRect(x: 1000, y: 0, width: 250, height: 500), "shown where its zone stands")
        XCTAssertTrue(coordinator.isScrolling)
        XCTAssertEqual(windows.frames[3]?.minX, 999, "the real windows wait at the edge under the pictures")
        XCTAssertEqual(windows.frames[1]?.minX, 999)
        run(1)
        let first = stage.shifts.last ?? 0
        XCTAssertLessThan(first, 0, "the pictures set off on the very next frame")
        XCTAssertGreaterThan(first, -250, "but they glide: they did not jump to the target")
        run(40)
        XCTAssertEqual(stage.shifts.last ?? 0, -250, accuracy: 1, "and arrived")
    }

    func testTheWindowsLandExactlyWhereTheyBelongAndThePicturesGoAway() {
        let scroller = scroller()
        scroller.start()
        scroller.scroll(toward: .right)
        XCTAssertTrue(coordinator.isScrolling, "gliding")
        run(60)
        settle()
        XCTAssertEqual(viewport.offset(for: key), 250)
        XCTAssertFalse(coordinator.isScrolling)
        XCTAssertEqual(windows.frames[3]?.minX, -250, "the front window stands in its zone")
        XCTAssertEqual(windows.frames[1]?.minX, -250, "so does the one behind")
        XCTAssertEqual(windows.frames[2]?.minX, 750, "and the one that was waiting beyond the edge")
        XCTAssertEqual(stage.finished, 1, "the pictures give way once the windows are in place")
    }

    func testAWindowThatChangedSizeWhileWaitingIsSetRightAtTheEnd() {
        let scroller = scroller()
        scroller.start()
        scroller.scroll(toward: .right)
        run(10)
        windows.setFrameDirectly(CGRect(x: 999, y: 0, width: 600, height: 300), of: 3)   // the system shrank it at the edge
        run(60)
        settle()
        XCTAssertEqual(windows.frames[3], CGRect(x: -250, y: 0, width: 1000, height: 500), "back at its size and place")
    }

    func testPicturesFromAnEarlierScrollAreUsedAndNoneAreTakenWhileTheLayoutGlides() {
        let scroller = scroller()
        scroller.start()
        scroller.scroll(toward: .right)
        run(60); settle()
        XCTAssertEqual(stage.begun.count, 1)
        scroller.scroll(toward: .left)   // back again
        run(60); settle()
        snapshots.answersAtOnce = false
        scroller.scroll(toward: .right)
        XCTAssertEqual(stage.begun.count, 3, "the glide begins without waiting for new photographs")
        snapshots.answer()
        XCTAssertEqual(stage.updates.count, 0, "no photographs are taken in the middle of the glide")
        run(60)
        settle()
    }

    func testAPictureStandsAtItsZonesCornerWhateverPlaceThePhotographSays() {
        // The list the photographs come from is old: it says the window is still where it was before it was moved.
        snapshots.images = [3: picture(CGRect(x: 640, y: 90, width: 1000, height: 500)), 2: picture(CGRect(x: 4000, y: 90, width: 250, height: 500))]
        let scroller = scroller()
        scroller.start()
        scroller.scroll(toward: .right)
        let frames = Dictionary(uniqueKeysWithValues: (stage.begun.first ?? []).map { ($0.id, $0.picture.frame) })
        XCTAssertEqual(frames[3], CGRect(x: 0, y: 0, width: 1000, height: 500), "at the corner of its zone, with the size it has")
        XCTAssertEqual(frames[2], CGRect(x: 1000, y: 0, width: 250, height: 500))
        run(60)
        settle()
    }

    func testFreshPicturesAreNotTakenAgain() {
        let scroller = scroller()
        scroller.start()
        scroller.scroll(toward: .right)
        run(60); settle()
        let before = snapshots.requests
        scroller.warm()
        XCTAssertEqual(snapshots.requests, before, "the pictures of a moment ago are good enough")
        run(1300)   // more than ten seconds of frames
        scroller.warm()
        XCTAssertEqual(snapshots.requests, before + 1, "older ones are taken again")
    }

    func testTheCoverWaitsForThePicturesOfZonesBeyondTheEdgeToo() {
        let both = snapshots.images
        snapshots.images = [3: both[3]!]   // only the window in view has been photographed so far
        let scroller = scroller()
        scroller.start()
        scroller.warm()
        snapshots.images = both
        snapshots.answersAtOnce = false
        scroller.scroll(toward: .right)
        XCTAssertTrue(stage.begun.isEmpty, "the window beyond the edge has no picture yet: the cover waits for the photographs")
        snapshots.answer()
        XCTAssertEqual(Set(stage.begun.first?.map(\.id) ?? []), [3, 2], "and then shows it too")
        run(60)
        settle()
    }

    func testWithoutPicturesTheWindowsMoveAtTheEnd() {
        snapshots.images = [:]
        let scroller = scroller()
        scroller.start()
        scroller.scroll(toward: .right)
        XCTAssertEqual(viewport.offset(for: key), 0, "waiting for pictures that do not come")
        RunLoop.current.run(until: Date().addingTimeInterval(1.7))
        XCTAssertEqual(viewport.offset(for: key), 250, "given up on: the windows move without them")
        XCTAssertTrue(stage.begun.isEmpty)
        XCTAssertFalse(coordinator.isScrolling)
    }

    func testReducedMotionPutsTheWindowsWithoutPicturesOrGliding() {
        reduceMotion = true
        let scroller = scroller()
        scroller.start()
        scroller.scroll(toward: .right)
        settle()
        XCTAssertTrue(stage.begun.isEmpty)
        XCTAssertEqual(viewport.offset(for: key), 250)
    }

    func testTheShortcutScrollsTheScreenUnderThePointerAndBackAgain() {
        let scroller = scroller()
        scroller.start()
        scroller.scroll(toward: .left)   // nothing beyond the left edge
        run(60); settle()
        XCTAssertEqual(viewport.offset(for: key), 0)
        scroller.scroll(toward: .right)
        run(60); settle()
        XCTAssertEqual(viewport.offset(for: key), 250)
        scroller.scroll(toward: .left)
        run(60); settle()
        XCTAssertEqual(viewport.offset(for: key), 0)
    }

    private func addAreaOnTheLeft() {
        var strip = repository.activeLayout(for: key)!.strip
        strip.leading = Overflow(width: 0.25, root: .leaf(UUID()))
        repository.setStrip(strip, ofLayout: repository.activeLayout(for: key)!.id, key: key)
        refresher.onRefresh()
    }

    func testAShortcutPressedWhileTheScrollGlidesCarriesItOnToTheNextRestPosition() {
        addAreaOnTheLeft()
        let scroller = scroller()
        scroller.start()
        XCTAssertTrue(scroller.scroll(toward: .left))
        run(60); settle()
        XCTAssertEqual(viewport.offset(for: key), -250)

        XCTAssertTrue(scroller.scroll(toward: .right))
        run(8)   // the pictures are gliding
        XCTAssertTrue(scroller.scroll(toward: .right), "carried on to the next rest position")
        XCTAssertFalse(scroller.scroll(toward: .right), "and there is none beyond it")
        run(80); settle()
        XCTAssertEqual(viewport.offset(for: key), 250)
        XCTAssertEqual(stage.begun.count, 2, "the pictures were put up once for the two presses")
    }

    func testAShortcutThePassingWayTurnsAGlidingScrollBack() {
        addAreaOnTheLeft()
        let scroller = scroller()
        scroller.start()
        XCTAssertTrue(scroller.scroll(toward: .right))
        run(8)
        XCTAssertTrue(scroller.scroll(toward: .left), "back toward where it came from")
        run(80); settle()
        XCTAssertEqual(viewport.offset(for: key), 0)
    }

    func testNothingScrollsWhileStageManagerHoldsTheWindows() {
        let busy = self.scroller(busy: true)
        XCTAssertFalse(busy.scroll(toward: .right))
        run(60)
        XCTAssertEqual(viewport.offset(for: key), 0)
        XCTAssertTrue(stage.begun.isEmpty)
    }

    func testAScreenWithoutAreasIgnoresTheShortcut() {
        _ = repository.addLayout(for: "plain|d1")
        screens.infos = [screen("plain|d1")]
        let scroller = scroller()
        scroller.start()
        XCTAssertFalse(scroller.scroll(toward: .right, on: screens.infos[0]))
        XCTAssertEqual(viewport.offset(for: "plain|d1"), 0)
        XCTAssertTrue(stage.begun.isEmpty)
    }

    func testZonesAreNamedOneTwoThreeOnTheScreenAndMinusAndPlusBeyondTheEdges() {
        var strip = repository.layout(id: repository.layouts(for: key)[0].id, key: key)!.strip
        let left = UUID()
        strip.leading = Overflow(root: .leaf(left))
        XCTAssertEqual(ZoneLabel.text(of: screenZone, in: strip), "1")
        XCTAssertEqual(ZoneLabel.text(of: areaZone, in: strip), "+1")
        XCTAssertEqual(ZoneLabel.text(of: left, in: strip), "-1")
        XCTAssertEqual(ZoneLabel.text(of: UUID(), in: strip), "?")
    }

    // MARK: The edge of the screen

    private final class FakePointerMoves: PointerMoveListening {
        private(set) var isListening = false
        private var onMove: ((CGPoint) -> Void)?
        func start(onMove: @escaping (CGPoint) -> Void) { isListening = true; self.onMove = onMove }
        func stop() { isListening = false; onMove = nil }
        func move(to point: CGPoint) { onMove?(point) }
    }

    private var pointerMoves: FakePointerMoves!
    private var edgeScrollerHeld: EdgeScroller?
    private var timers: [(delay: TimeInterval, work: () -> Void, cancelled: Bool)] = []

    private func edgeScroller() -> EdgeScroller {
        pointerMoves = FakePointerMoves()
        timers = []
        let edge = EdgeScroller(listener: pointerMoves, screens: screens, settings: settings, scroller: scroller(), dwell: 1) { [unowned self] delay, work in
            timers.append((delay, work, false))
            let index = timers.count - 1
            return { [unowned self] in timers[index].cancelled = true }
        }
        edge.start()
        edgeScrollerHeld = edge
        return edge
    }

    /// The moment the pointer has rested for the time: the last timer that was not cancelled goes off.
    private func rest() { timers.last { !$0.cancelled }?.work() }

    func testRestingThePointerAtTheRightEdgeScrollsAndLeavingItBackAgain() {
        _ = edgeScroller()
        pointer_(at: 999.5)
        XCTAssertEqual(timers.count, 1)
        XCTAssertEqual(timers.first?.delay, 1, "after a second")
        XCTAssertEqual(viewport.offset(for: key), 0)
        screens.pointerCocoa = CGPoint(x: 999.5, y: 250)
        rest()
        run(60); settle()
        XCTAssertEqual(viewport.offset(for: key), 250, "the area beyond the right edge came into view")

        // Still at the edge: nothing again until it has left and come back.
        pointer_(at: 999.5)
        pointer_(at: 998.8)
        XCTAssertEqual(timers.count, 1, "no new wait while it has not left the edge")
        pointer_(at: 500)
        pointer_(at: 0.5)   // the left edge now: back
        XCTAssertEqual(timers.count, 1, "going back waits for nothing")
        run(60); settle()
        XCTAssertEqual(viewport.offset(for: key), 0, "back to the screen's own layout at once")
    }

    func testMovingThePointerAroundTheMiddleOfTheScreenAsksNothingOfTheDockOrTheDesktops() {
        _ = edgeScroller()
        let before = screens.screensCalls
        for x in stride(from: 100.0, through: 900.0, by: 100) { pointer_(at: x) }
        XCTAssertEqual(screens.screensCalls, before, "this runs on every mouse move: only plain frames are read")
    }

    func testThePointerLeavingTheEdgeBeforeTheTimeCancelsIt() {
        _ = edgeScroller()
        pointer_(at: 999.5)
        pointer_(at: 600)
        XCTAssertTrue(timers.first?.cancelled == true)
        screens.pointerCocoa = CGPoint(x: 600, y: 250)
        rest()
        XCTAssertEqual(viewport.offset(for: key), 0)
    }

    func testNothingScrollsWhereThereIsNothingMoreAndNotWhileTheZonesAreSwitchedOff() {
        let edge = edgeScroller()
        pointer_(at: 0.5)   // the left edge: no area that way
        screens.pointerCocoa = CGPoint(x: 0.5, y: 250)
        rest()
        run(60); settle()
        XCTAssertEqual(viewport.offset(for: key), 0)
        XCTAssertTrue(stage.begun.isEmpty)

        settings.values.overflowZonesEnabled = false
        edge.settingDidChange()
        XCTAssertFalse(pointerMoves.isListening, "the pointer is not watched while the setting is off")
    }

    private func pointer_(at x: CGFloat) { pointerMoves.move(to: CGPoint(x: x, y: 250)) }
}
