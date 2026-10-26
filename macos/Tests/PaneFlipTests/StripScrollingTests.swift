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
        strip.trailing = [Overflow(width: 0.25, root: .leaf(areaZone))]
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

    /// A screen with nothing placed on it: no window in any zone.
    private func emptyTheZones() {
        for stack in coordinator.stacks.values {
            stack.refs = [:]
            stack.tabs = []
            stack.activeID = nil
        }
    }

    func testAZoneBeyondTheEdgeWaitsWithOnePixelOnTheScreen() {
        let plan = planner.plan(on: screens.infos)
        XCTAssertEqual(plan[screenZone], PlannedZone(rect: CGRect(x: 0, y: 0, width: 1000, height: 500), number: 1))
        XCTAssertEqual(plan[areaZone]?.rect, CGRect(x: 1000, y: 0, width: 250, height: 500))
        XCTAssertEqual(plan[areaZone]?.frame, CGRect(x: 999, y: 0, width: 250, height: 500))
        XCTAssertEqual(plan[areaZone]?.isParked, true)
        XCTAssertEqual(plan[areaZone]?.number, 1, "numbered from the screen outwards, as the zone is shown")
    }

    func testAZoneBeyondTheEdgeIsToldWhereItWillStandAfterTheScroll() {
        let screen = screens.infos[0]
        let predicted = planner.rect(of: areaZone, at: 250, on: screen, among: screens.infos)
        XCTAssertNotNil(predicted)
        viewport.set(250, for: screen.key)
        XCTAssertEqual(planner.plan(on: screens.infos)[areaZone]?.rect, predicted, "the rectangle the plan gives once it has scrolled there")
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

    func testTheFocusGoingToAWindowBeyondTheEdgeScrollsToIt() {
        let scroller = scroller()
        scroller.start()
        XCTAssertFalse(scroller.reveal(zone: screenZone), "a zone in view needs no scroll")
        XCTAssertFalse(scroller.reveal(zone: UUID()), "nor one that is not there")

        XCTAssertTrue(scroller.reveal(zone: areaZone))
        XCTAssertTrue(coordinator.isScrolling)
        XCTAssertFalse(scroller.reveal(zone: areaZone), "not again while it scrolls")
    }

    /// A screen of two zones (the line at 40 %) with a whole screen beyond its right edge, also of two zones (the line in the middle).
    private func setUpZoneLines() -> UUID {
        let rightOfScreen = UUID(), rightOfArea = UUID()
        var strip = repository.activeLayout(for: key)!.strip
        strip.root = .split(id: UUID(), sideBySide: true, ratio: 0.4, first: .leaf(screenZone), second: .leaf(rightOfScreen))
        strip.trailing = [Overflow(width: 1, root: .split(id: UUID(), sideBySide: true, ratio: 0.5, first: .leaf(areaZone), second: .leaf(rightOfArea)))]
        repository.setStrip(strip, ofLayout: repository.activeLayout(for: key)!.id, key: key)
        refresher.onRefresh()
        return rightOfArea
    }

    func testEachLineBetweenZonesIsAStopOfTheScroll() {
        _ = setUpZoneLines()
        let scroller = scroller()
        scroller.start()

        var stops: [CGFloat] = []
        for _ in 0 ..< 5 {
            scroller.scroll(toward: .right)
            for _ in 0 ..< 4 { run(60); settle() }
            stops.append(viewport.offset(for: key))
        }
        XCTAssertEqual(stops, [400, 500, 1000, 1000, 1000],
                       "the second zone of the screen first, then the first zone of the area in whole, then the area; not past the end")

        var back: [CGFloat] = []
        for _ in 0 ..< 4 {
            scroller.scroll(toward: .left)
            for _ in 0 ..< 4 { run(60); settle() }
            back.append(viewport.offset(for: key))
        }
        XCTAssertEqual(back, [500, 400, 0, 0], "and the same stops on the way back")
    }

    func testPressesWhileAScrollLandsAreNotLostAndGoOnWhenItIsOver() {
        _ = setUpZoneLines()
        let scroller = scroller()
        scroller.start()

        XCTAssertTrue(scroller.scroll(toward: .right))
        run(60)   // the pictures have glided to the first stop: the windows land, the pictures have not given way yet
        XCTAssertTrue(scroller.scroll(toward: .right), "a press while it lands waits for the landing, it is not dropped")
        XCTAssertTrue(scroller.scroll(toward: .right))
        XCTAssertEqual(viewport.offset(for: key), 400)

        for _ in 0 ..< 4 { settle(); run(60) }
        XCTAssertEqual(viewport.offset(for: key), 1000, "both went on from there, one stop each")
    }

    func testFingersTakeOverAScrollThatAKeyStartedWhileItGlides() {
        _ = setUpZoneLines()
        let scroller = scroller()
        scroller.start()

        XCTAssertTrue(scroller.scroll(toward: .right))   // a key: the next stop, a glide of its own
        run(12)
        let glidingAt = stage.shifts.last ?? 0
        XCTAssertLessThan(glidingAt, 0)

        XCTAssertTrue(scroller.beginLed(), "two fingers come down: the glide is theirs, nothing has to be waited for")
        let shifts = stage.shifts.count
        run(60)
        XCTAssertEqual(stage.shifts.count, shifts, "it waits for the fingers")
        scroller.moveLed(by: -30, at: 1.0)
        XCTAssertEqual(stage.shifts.last ?? 0, glidingAt - 30, accuracy: 0.001, "the layout follows them from where it was")
        scroller.endLed()
        for _ in 0 ..< 4 { settle(); run(60) }
        let nearest = ([0, 400, 500, 1000] as [CGFloat]).min { abs($0 - (30 - glidingAt)) < abs($1 - (30 - glidingAt)) }
        XCTAssertEqual(viewport.offset(for: key), nearest, "and comes to rest at the stop nearest to where they let go")
    }

    func testFingersTakeOverAScrollWhileItLandsAndGoOnFromWhereItCameToRest() {
        _ = setUpZoneLines()
        let scroller = scroller()
        scroller.start()

        XCTAssertTrue(scroller.scroll(toward: .right))
        run(60)   // the glide is over: the windows are being put in their places
        XCTAssertEqual(viewport.offset(for: key), 400)
        let finished = stage.finished

        XCTAssertTrue(scroller.beginLed(), "two fingers come down while it lands: no waiting for the pictures to give way")
        XCTAssertEqual(stage.kept, 1, "the pictures stay on the stage")
        scroller.moveLed(by: -60, at: 0)
        XCTAssertEqual(stage.shifts.last, -460, "they follow the fingers from the stop it came to (400), 60 points on")
        scroller.endLed()
        for _ in 0 ..< 4 { settle(); run(60) }
        XCTAssertEqual(viewport.offset(for: key), 500, "and come to rest at the nearest stop")
        XCTAssertEqual(stage.finished, finished + 1, "the pictures gave way once, after the second scroll")
    }

    func testAPressWhileAScrollLandsStartsTheNextScrollAtOnce() {
        _ = setUpZoneLines()
        let scroller = scroller()
        scroller.start()

        XCTAssertTrue(scroller.scroll(toward: .right))
        run(60)
        let shifts = stage.shifts.count
        XCTAssertTrue(scroller.scroll(toward: .right), "the key is pressed while it lands")
        run(10)
        XCTAssertGreaterThan(stage.shifts.count, shifts, "the pictures are on their way to the next stop already")
        XCTAssertEqual(stage.kept, 1)
        for _ in 0 ..< 4 { settle(); run(60) }
        XCTAssertEqual(viewport.offset(for: key), 500)
    }

    func testKeysAndWheelStepOneStopEachInEitherDirectionWhateverTheScrollIsDoing() {
        _ = setUpZoneLines()   // stops at 0, 400, 500 and 1000
        let scroller = scroller()
        scroller.start()

        // Before the pictures are there, while they glide, while it lands (the glide over, the windows being written): none is lost.
        XCTAssertTrue(scroller.scroll(toward: .right))        // 400
        XCTAssertTrue(scroller.scroll(toward: .right))        // 500
        XCTAssertTrue(scroller.scroll(toward: .left))         // back to 400, turned round before anything has moved
        run(8)
        XCTAssertTrue(scroller.scroll(toward: .right))        // 500 again, from where the pictures are
        XCTAssertTrue(scroller.scroll(toward: .right))        // 1000
        run(80)                                               // it lands at 1000
        XCTAssertTrue(scroller.scroll(toward: .left), "while it lands: the next scroll starts at once, back one stop")
        XCTAssertTrue(scroller.scroll(toward: .left))
        for _ in 0 ..< 5 { settle(); run(60) }
        XCTAssertEqual(viewport.offset(for: key), 400, "1000, one stop back, one more: 400")
    }

    func testAPressWithNoStopBeyondIsNotKeptForLater() {
        let scroller = scroller()
        scroller.start()
        XCTAssertTrue(scroller.scroll(toward: .right))   // the only stop beyond the screen
        run(60)
        XCTAssertFalse(scroller.scroll(toward: .right), "nothing further that way, nothing to wait for")
        for _ in 0 ..< 4 { settle(); run(60) }
        XCTAssertEqual(viewport.offset(for: key), 250)
    }

    func testRevealingAZoneBringsInAllOfItNotASliverOfIt() {
        _ = setUpZoneLines()
        let scroller = scroller()
        scroller.start()

        XCTAssertTrue(scroller.reveal(zone: areaZone))
        for _ in 0 ..< 4 { run(60); settle() }
        XCTAssertEqual(viewport.offset(for: key), 500, "at 400 only 40 % of it would show: the first stop that shows all of it")
    }

    func testRevealingAFarAreaScrollsStraightToIt() {
        let far = UUID()
        var strip = repository.activeLayout(for: key)!.strip
        strip.trailing.append(Overflow(width: 0.5, root: .leaf(far)))
        repository.setStrip(strip, ofLayout: repository.activeLayout(for: key)!.id, key: key)
        refresher.onRefresh()
        let scroller = scroller()
        scroller.start()

        XCTAssertTrue(scroller.reveal(zone: far))
        run(60); settle()

        XCTAssertEqual(viewport.offset(for: key), 750, "straight to the area that holds the zone, in one scroll")
        XCTAssertFalse(scroller.reveal(zone: far), "it shows now: nothing more")
    }

    func testAScrollOfTheUsersOwnEndsWhatAFocusChangeAskedFor() {
        let far = UUID()
        var strip = repository.activeLayout(for: key)!.strip
        strip.trailing.append(Overflow(width: 0.5, root: .leaf(far)))
        repository.setStrip(strip, ofLayout: repository.activeLayout(for: key)!.id, key: key)
        refresher.onRefresh()
        let scroller = scroller()
        scroller.start()

        XCTAssertTrue(scroller.reveal(zone: far))
        scroller.scroll(toward: .left)   // the user turns it round while it runs
        for _ in 0 ..< 4 { run(60); settle() }

        XCTAssertLessThan(viewport.offset(for: key), 750, "it did not go on to the zone")
    }

    func testTheFingersLeadTheLayoutAndItComesToRestAtTheNearestRestPosition() {
        let scroller = scroller()
        scroller.start()

        XCTAssertTrue(scroller.beginLed())
        for _ in 0 ..< 3 { run(30); settle() }   // the pictures cover the screen
        scroller.moveLed(by: -100, at: 0)
        scroller.moveLed(by: -100, at: 0.5)
        XCTAssertEqual(stage.shifts.last, -200, "the pictures follow the fingers: the area beyond the right edge comes in")
        scroller.moveLed(by: -50, at: 1.0)
        scroller.endLed()
        for _ in 0 ..< 4 { run(60); settle() }

        XCTAssertEqual(viewport.offset(for: key), 250, "the rest position beyond: the area is in view")
    }

    func testTheFingersCannotTakeTheLayoutPastItsFirstOrItsLastPosition() {
        let scroller = scroller()
        scroller.start()

        XCTAssertTrue(scroller.beginLed())
        for _ in 0 ..< 3 { run(30); settle() }
        scroller.moveLed(by: 300, at: 0)
        XCTAssertEqual(stage.shifts.last, 0, "nothing beyond the first position gives way")
        scroller.moveLed(by: -900, at: 0.5)
        XCTAssertEqual(stage.shifts.last, -250, "nor beyond the last: the area beyond the edge is just in view")
        scroller.moveLed(by: 40, at: 1.0)
        XCTAssertEqual(stage.shifts.last, -210, "going back is followed at once")
        scroller.endLed()
    }

    func testNewFingersTakeTheLayoutOverWhileItStillGlidesToItsRest() {
        let scroller = scroller()
        scroller.start()

        XCTAssertTrue(scroller.beginLed())
        for _ in 0 ..< 3 { run(30); settle() }
        scroller.moveLed(by: -200, at: 0)
        scroller.endLed()
        run(10)   // a little way into the glide toward the rest position beyond
        let glidingAt = stage.shifts.last
        XCTAssertNotEqual(glidingAt, 0)

        XCTAssertTrue(scroller.beginLed(), "the fingers come down again: the glide is theirs")
        let shifts = stage.shifts.count
        run(60)
        XCTAssertEqual(stage.shifts.count, shifts, "the glide waits for the fingers, it does not go on by itself")

        scroller.moveLed(by: 20, at: 1.0)
        XCTAssertEqual(stage.shifts.last ?? 0, (glidingAt ?? 0) + 20, accuracy: 0.001, "the layout follows them from where it was")
        scroller.moveLed(by: 400, at: 1.3)
        XCTAssertEqual(stage.shifts.last, 0, "taken back past where it began, it stops at the first position")
        scroller.endLed()
        for _ in 0 ..< 4 { run(60); settle() }
        XCTAssertEqual(viewport.offset(for: key), 0, "and comes to rest there")
    }

    func testAShortSwipeGoesBackToWhereTheLayoutWas() {
        let scroller = scroller()
        scroller.start()

        XCTAssertTrue(scroller.beginLed())
        for _ in 0 ..< 3 { run(30); settle() }
        scroller.moveLed(by: -30, at: 0)
        scroller.moveLed(by: -10, at: 0.6)
        scroller.endLed()
        for _ in 0 ..< 4 { run(60); settle() }

        XCTAssertEqual(viewport.offset(for: key), 0)
    }

    func testTheFingersMayLiftBeforeThePicturesAreOnTheStage() {
        let scroller = scroller()
        scroller.start()

        XCTAssertTrue(scroller.beginLed())
        scroller.moveLed(by: -200, at: 0)
        scroller.endLed()
        for _ in 0 ..< 5 { run(60); settle() }

        XCTAssertEqual(viewport.offset(for: key), 250)
    }

    func testTheCoordinatorAsksForTheScrollWhenTheFocusIsOnAParkedWindow() {
        var asked: [UUID] = []
        coordinator.onFocusBeyondTheEdge = { asked.append($0) }

        windows.focused = .fake(3)
        coordinator.followFocus()
        XCTAssertEqual(asked, [], "a window in view")

        windows.focused = .fake(2)
        coordinator.followFocus()
        XCTAssertEqual(asked, [areaZone])

        coordinator.followFocus()
        coordinator.followFocus()
        XCTAssertEqual(asked, [areaZone], "the focus staying there does not ask again: a scroll away from it is not undone")

        windows.focused = .fake(3)
        coordinator.followFocus()
        windows.focused = .fake(2)
        coordinator.followFocus()
        XCTAssertEqual(asked, [areaZone, areaZone], "going back to it asks again")
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

    func testAScreenWithNoWindowsStillGlidesForTheFrameOfTheIsland() {
        emptyTheZones()
        let scroller = scroller()
        var froms: [CGFloat?] = [], tos: [CGFloat] = []
        scroller.onGlide = { _, from, to in froms.append(from); tos.append(to) }
        scroller.start()

        XCTAssertTrue(scroller.scroll(toward: .right))

        XCTAssertEqual(tos, [250], "the island is told at once, as it is when there are pictures")
        XCTAssertEqual(froms, [0])
        XCTAssertEqual(viewport.offset(for: key), 0, "the layout waits for the glide")
        XCTAssertTrue(coordinator.isScrolling, "the island keeps its picture while the frame glides")
        XCTAssertTrue(stage.begun.isEmpty, "nothing to put on the stage")
        run(60); settle()
        XCTAssertEqual(viewport.offset(for: key), 250)
        XCTAssertFalse(coordinator.isScrolling)
    }

    func testTheFingersLeadAScreenWithNoWindowsToo() {
        emptyTheZones()
        let scroller = scroller()
        var follows: [CGFloat] = [], tos: [CGFloat] = []
        scroller.onFollow = { _, offset in follows.append(offset) }
        scroller.onGlide = { _, _, to in tos.append(to) }
        scroller.start()

        XCTAssertTrue(scroller.beginLed(), "nothing to photograph: the fingers lead at once")
        scroller.moveLed(by: -100, at: 0)
        scroller.moveLed(by: -100, at: 0.5)
        XCTAssertEqual(follows.last, 200, "the frame of the island follows the fingers")
        scroller.moveLed(by: -50, at: 1.0)
        scroller.endLed()
        XCTAssertEqual(tos, [250], "and glides on to the nearest rest position")
        for _ in 0 ..< 4 { run(60); settle() }

        XCTAssertEqual(viewport.offset(for: key), 250)
        XCTAssertFalse(coordinator.isScrolling)
    }

    func testReducedMotionWithNoWindowsDoesNotGlideEither() {
        emptyTheZones()
        reduceMotion = true
        let scroller = scroller()
        var glides = 0
        scroller.onGlide = { _, _, _ in glides += 1 }
        scroller.start()
        XCTAssertFalse(scroller.beginLed(), "motion is reduced: the caller steps on lifting")
        scroller.scroll(toward: .right)
        settle()
        XCTAssertEqual(glides, 0)
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
        strip.leading = [Overflow(width: 0.25, root: .leaf(UUID()))]
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
        strip.leading = [Overflow(root: .leaf(left))]
        XCTAssertEqual(ZoneLabel.text(of: screenZone, in: strip), "1")
        XCTAssertEqual(ZoneLabel.text(of: areaZone, in: strip), "+1")
        XCTAssertEqual(ZoneLabel.text(of: left, in: strip), "-1")
        XCTAssertEqual(ZoneLabel.text(of: UUID(), in: strip), "?")
    }

    // MARK: Scrolling through many areas

    func testScrollingGoesOnAreaByAreaThroughAsManyAreasAsThereAre() {
        var strip = repository.activeLayout(for: key)!.strip
        strip.trailing.append(Overflow(width: 0.5, root: .leaf(UUID())))
        repository.setStrip(strip, ofLayout: repository.activeLayout(for: key)!.id, key: key)
        let scroller = scroller()
        scroller.start()

        for expected in [250.0, 750.0] {
            XCTAssertTrue(scroller.scroll(toward: .right))
            run(60); settle()
            XCTAssertEqual(viewport.offset(for: key), CGFloat(expected), "the far edge of the next area")
        }
        XCTAssertFalse(scroller.scroll(toward: .right), "nothing more that way")
        XCTAssertTrue(scroller.scroll(toward: .left))
        run(60); settle()
        XCTAssertEqual(viewport.offset(for: key), 250)
    }
}
