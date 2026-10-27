import XCTest
import CoreGraphics
import PaneFlipCore

final class StackCoordinatorTests: XCTestCase {
    private var windows: FakeWindowSystem!
    private var memory: StackMemory!
    private var coordinator: StackCoordinator!
    private var settings: AppSettings!

    override func setUp() {
        windows = FakeWindowSystem()
        memory = StackMemory(store: MemoryDocumentStore())
        settings = AppSettings(storage: StubSettingsStorage())
        coordinator = StackCoordinator(windows: windows, memory: memory, settings: settings, apps: FakeApps())
    }

    /// Two neighbours widened by 4 pt overlap at the edge. Which one wins must not depend on set order.
    func testDropOnTheEdgeBetweenZonesGoesToTheZoneThatHoldsThePoint() {
        for _ in 0..<30 {   // fresh ids every time, so the set order differs
            let left = UUID(), right = UUID()
            coordinator.apply(zones: [left: CGRect(x: 0, y: 0, width: 100, height: 100),
                                      right: CGRect(x: 100, y: 0, width: 100, height: 100)])
            XCTAssertEqual(coordinator.zoneID(at: CGPoint(x: 101, y: 50)), right)
            XCTAssertEqual(coordinator.zoneID(at: CGPoint(x: 99, y: 50)), left)
        }
    }

    func testASwipeThroughWindowsNeedsAZoneUnderThePointerThatHoldsSeveral() {
        let zone = UUID()
        coordinator.apply(zones: [zone: CGRect(x: 0, y: 0, width: 100, height: 100)])
        XCTAssertFalse(coordinator.canScrubWindows(at: CGPoint(x: 50, y: 50)), "an empty zone has nothing to swipe through")
        XCTAssertFalse(coordinator.canScrubWindows(at: CGPoint(x: 500, y: 500)))
    }

    func testPointJustOutsideAZoneStillCountsThroughTheMargin() {
        let zone = UUID()
        coordinator.apply(zones: [zone: CGRect(x: 0, y: 0, width: 100, height: 100)])
        XCTAssertEqual(coordinator.zoneID(at: CGPoint(x: 102, y: 50)), zone)
        XCTAssertNil(coordinator.zoneID(at: CGPoint(x: 120, y: 50)))
    }

    func testADroppedWindowGlidesToItsZoneButARestoredOneJumps() {
        let zone = UUID(), rect = CGRect(x: 0, y: 0, width: 100, height: 100)
        coordinator.glide = WindowGlide(windows: windows, reduceMotion: { false }, background: { _ in })
        coordinator.apply(zones: [zone: rect])
        windows.setFrame(CGRect(x: 300, y: 300, width: 50, height: 50), of: .fake(1))
        coordinator.snap(.fake(1), into: zone)
        XCTAssertNotEqual(windows.frames[1], rect, "left to the glide, which has not run yet")
        XCTAssertEqual(windows.raised, [1])
        XCTAssertEqual(coordinator.stacks[zone]?.activeID, 1)

        let slot = memory.remember(zoneID: zone, bundleID: "", title: "")
        coordinator.attach(.fake(2), toSlot: slot, raise: false)
        XCTAssertEqual(windows.frames[2], rect)
    }

    func testTheFocusGoesToTheFrontWindowOfTheZoneBesideTheFocusedOne() {
        let left = UUID(), topRight = UUID(), bottomRight = UUID()
        coordinator.apply(zones: [left: CGRect(x: 0, y: 0, width: 500, height: 800), topRight: CGRect(x: 504, y: 0, width: 496, height: 400),
                                  bottomRight: CGRect(x: 504, y: 404, width: 496, height: 396)])
        coordinator.snap(.fake(1), into: left)
        coordinator.snap(.fake(2), into: topRight)
        windows.focused = .fake(1)
        var flashed: [CGRect] = []
        coordinator.flashZone = { flashed.append($0) }

        let raisedBefore = windows.raised.count
        coordinator.focusZone(toward: .left)
        XCTAssertEqual(windows.raised.count, raisedBefore, "nothing is left of the first zone: the focus stays")
        coordinator.focusZone(toward: .right)
        XCTAssertEqual(windows.raised.last, 2)
        XCTAssertEqual(flashed, [CGRect(x: 504, y: 0, width: 496, height: 400)], "the zone it reached is highlighted: no frame travels")
        windows.focused = .fake(2)   // the app has caught up
        coordinator.followFocus()
        coordinator.focusZone(toward: .down)
        XCTAssertEqual(windows.raised.last, 2, "the zone below holds no window")
        coordinator.focusZone(toward: .left)
        XCTAssertEqual(windows.raised.last, 1)
        XCTAssertEqual(flashed.count, 2, "nothing is shown where the focus does not move")
    }

    func testTheFocusIsAskedOffTheMainThreadOneQuestionAtATime() {
        let zone = UUID()
        coordinator.apply(zones: [zone: CGRect(x: 0, y: 0, width: 500, height: 800)])
        coordinator.snap(.fake(1), into: zone)
        windows.focused = .fake(1)
        var queued: [() -> Void] = []
        coordinator.focusQueue = { queued.append($0) }

        coordinator.followFocus()
        coordinator.followFocus()
        coordinator.followFocus()
        XCTAssertEqual(queued.count, 1, "the others wait for the answer")
        XCTAssertNil(coordinator.focusedZoneID, "nothing is known before the answer comes")

        queued.removeFirst()()   // the question is answered off the main thread
        let answered = expectation(description: "the answer is taken on the main thread")
        DispatchQueue.main.async { answered.fulfill() }
        wait(for: [answered], timeout: 2)
        XCTAssertEqual(coordinator.focusedZoneID, zone)
        XCTAssertEqual(queued.count, 1, "the question that came meanwhile is asked once more")
    }

    func testQuickPressesGoOnFromWhereTheLastOneWentBeforeTheAppHasCaughtUp() {
        let a = UUID(), b = UUID(), c = UUID()
        coordinator.apply(zones: [a: CGRect(x: 0, y: 0, width: 300, height: 800), b: CGRect(x: 304, y: 0, width: 300, height: 800),
                                  c: CGRect(x: 608, y: 0, width: 300, height: 800)])
        [(1, a), (2, b), (3, c)].forEach { coordinator.snap(.fake(CGWindowID($0.0)), into: $0.1) }
        windows.focused = .fake(1)   // and the app goes on saying so
        coordinator.followFocus()

        coordinator.focusZone(toward: .right)
        coordinator.focusZone(toward: .right)
        XCTAssertEqual(windows.raised.suffix(2), [2, 3], "the second press starts from the zone the first one went to")
        XCTAssertEqual(coordinator.focusedZoneID, c)
        coordinator.focusZone(toward: .left)
        XCTAssertEqual(windows.raised.last, 2)
    }

    func testAClickOnAZoneOfTheIslandBringsTheFocusThereUnlessItIsThereAlready() {
        let left = UUID(), right = UUID(), empty = UUID()
        let leftRect = CGRect(x: 0, y: 0, width: 500, height: 800), rightRect = CGRect(x: 504, y: 0, width: 496, height: 400)
        coordinator.apply(zones: [left: leftRect, right: rightRect, empty: CGRect(x: 504, y: 404, width: 496, height: 396)])
        coordinator.snap(.fake(1), into: left)
        coordinator.snap(.fake(2), into: right)
        windows.focused = .fake(1)
        coordinator.followFocus()
        var flashed: [CGRect] = []
        coordinator.flashZone = { flashed.append($0) }

        coordinator.focus(zone: left)
        XCTAssertTrue(flashed.isEmpty, "the focus is in that zone already")
        coordinator.focus(zone: empty)
        XCTAssertTrue(flashed.isEmpty, "a zone with no window has nothing to focus")
        coordinator.focus(zone: right)
        XCTAssertEqual(windows.raised.last, 2)
        XCTAssertTrue(flashed.isEmpty, "a click on the island shows no frame: the zone takes the focus at once")
        XCTAssertEqual(coordinator.focusedZoneID, right, "the highlight does not wait for the app to take the focus")
        coordinator.followFocus()   // the app has not caught up yet: it still says the first window has the focus
        XCTAssertEqual(coordinator.focusedZoneID, right, "an answer that is behind is not believed")
        windows.focused = .fake(2)
        coordinator.followFocus()
        XCTAssertEqual(coordinator.focusedZoneID, right)
        windows.focused = .fake(1)
        coordinator.followFocus()
        XCTAssertEqual(coordinator.focusedZoneID, left, "once seen there, the focus is read as it is")
    }

    func testQuickPressesGoOnThroughSeveralZonesBeyondTheEdge() {
        let screenZone = UUID(), first = UUID(), second = UUID()
        let here = CGRect(x: 0, y: 0, width: 1000, height: 800)
        coordinator.apply(plan: [screenZone: PlannedZone(rect: here),
                                 first: PlannedZone(rect: CGRect(x: 1000, y: 0, width: 1000, height: 800), frame: CGRect(x: 999, y: 0, width: 1000, height: 800), isParked: true),
                                 second: PlannedZone(rect: CGRect(x: 2000, y: 0, width: 1000, height: 800), frame: CGRect(x: 999, y: 0, width: 1000, height: 800), isParked: true)])
        coordinator.snap(.fake(1), into: screenZone)
        coordinator.snap(.fake(2), into: first)
        coordinator.snap(.fake(3), into: second)
        windows.focused = .fake(1)
        coordinator.followFocus()
        var asked: [UUID] = []
        coordinator.onReachBeyondTheEdge = { zone, told in asked.append(zone); told(here); return true }

        coordinator.focusZone(toward: .right)
        coordinator.focusZone(toward: .right)   // before the first scroll is over
        XCTAssertEqual(asked, [first, second], "the second press goes on from the zone the first one asked for")
    }

    func testAClickOnAZoneBeyondTheEdgeAsksTheLayoutToBringItIntoView() {
        let here = UUID(), beyond = UUID()
        coordinator.apply(plan: [here: PlannedZone(rect: CGRect(x: 0, y: 0, width: 1000, height: 800)),
                                 beyond: PlannedZone(rect: CGRect(x: 1000, y: 0, width: 1000, height: 800), frame: CGRect(x: 999, y: 0, width: 1000, height: 800), isParked: true)])
        coordinator.snap(.fake(1), into: here)
        coordinator.snap(.fake(2), into: beyond)
        windows.focused = .fake(1)
        coordinator.followFocus()
        var asked: [UUID] = []
        var flashed: [CGRect] = []
        coordinator.flashZone = { flashed.append($0) }
        coordinator.onReachBeyondTheEdge = { zone, told in asked.append(zone); told(CGRect(x: 0, y: 0, width: 1000, height: 800)); return true }

        coordinator.focus(zone: beyond)
        XCTAssertEqual(asked, [beyond])
        XCTAssertTrue(flashed.isEmpty, "a click on the island shows no frame")
        XCTAssertEqual(coordinator.focusedZoneID, beyond, "the highlight does not wait for the scroll")
    }

    func testAClickOnAZoneOfTheScreenWhileTheLayoutIsScrolledAwayScrollsBackBeforeTheWindowComesForward() {
        let a = UUID(), b = UUID()
        coordinator.apply(zones: [a: CGRect(x: 0, y: 0, width: 500, height: 800), b: CGRect(x: 504, y: 0, width: 496, height: 800)])
        coordinator.snap(.fake(1), into: a)
        coordinator.snap(.fake(2), into: b)
        windows.focused = .fake(1)
        coordinator.followFocus()
        var flashed: [CGRect] = []
        coordinator.flashZone = { flashed.append($0) }
        var asked: [UUID] = []
        coordinator.onReachBeyondTheEdge = { zone, _ in asked.append(zone); return true }
        let raised = windows.raised.count

        coordinator.focus(zone: b)
        XCTAssertEqual(asked, [b])
        XCTAssertEqual(windows.raised.count, raised, "the window comes forward when the layout has scrolled back")
        XCTAssertTrue(flashed.isEmpty, "a click on the island shows no frame")
        coordinator.finishFocusBeyondTheEdge()
        XCTAssertEqual(windows.raised.last, 2)
    }

    func testGoingLeftOfTwoZonesOnTopOfEachOtherTakesTheOneThatFollowsInTheOrderOfTheZones() {
        // 1 / 2 | 3 | 4 / 5 | +1 : the order of the zones is 1, 2, 3, 4, 5, +1.
        let ids = (0 ..< 6).map { _ in UUID() }
        let rects = [CGRect(x: 0, y: 0, width: 300, height: 400), CGRect(x: 0, y: 404, width: 300, height: 396), CGRect(x: 304, y: 0, width: 300, height: 800),
                     CGRect(x: 608, y: 0, width: 300, height: 400), CGRect(x: 608, y: 404, width: 300, height: 396), CGRect(x: 912, y: 0, width: 300, height: 800)]
        var plan: [UUID: PlannedZone] = [:]
        for (i, id) in ids.enumerated() {
            plan[id] = PlannedZone(rect: rects[i], frame: i == 5 ? CGRect(x: 999, y: 0, width: 300, height: 800) : nil, isParked: i == 5, order: i)
            coordinator.apply(plan: plan)
        }
        for (i, id) in ids.enumerated() { coordinator.snap(.fake(CGWindowID(i + 1)), into: id) }
        windows.focused = .fake(6)
        coordinator.followFocus()

        coordinator.focusZone(toward: .left)
        XCTAssertEqual(windows.raised.last, 5, "from +1 the zone 5, which comes before it, not the zone 4")
        coordinator.focusZone(toward: .left)
        XCTAssertEqual(windows.raised.last, 3)
        coordinator.focusZone(toward: .left)
        XCTAssertEqual(windows.raised.last, 2, "from 3 the zone 2, which comes before it, not the zone 1")
    }

    func testPressesBackAndForthWhileTheLayoutScrollsEndOnTheLastZoneAskedFor() {
        let screenZone = UUID(), first = UUID(), second = UUID()
        let here = CGRect(x: 0, y: 0, width: 1000, height: 800)
        let beyondFrame = CGRect(x: 999, y: 0, width: 1000, height: 800)
        func plan(parked: Bool) -> [UUID: PlannedZone] {
            [screenZone: PlannedZone(rect: here),
             first: PlannedZone(rect: CGRect(x: 1000, y: 0, width: 1000, height: 800), frame: beyondFrame, isParked: parked),
             second: PlannedZone(rect: CGRect(x: 2000, y: 0, width: 1000, height: 800), frame: beyondFrame, isParked: true)]
        }
        coordinator.apply(plan: plan(parked: true))
        [(1, screenZone), (2, first), (3, second)].forEach { coordinator.snap(.fake(CGWindowID($0.0)), into: $0.1) }
        windows.focused = .fake(1)
        coordinator.followFocus()
        var asked: [UUID] = []
        coordinator.onReachBeyondTheEdge = { zone, _ in asked.append(zone); return true }
        coordinator.isScrolling = true   // the layout is on its way to the first zone
        let raisedBefore = windows.raised.count

        coordinator.focusZone(toward: .right)   // first
        coordinator.focusZone(toward: .right)   // second
        coordinator.focusZone(toward: .left)    // first again
        coordinator.focusZone(toward: .left)    // back on the screen's own zone, which the scroll is taking away
        XCTAssertEqual(asked, [first, second, first, screenZone], "every press goes on from where the last one went, whatever the scroll does")
        XCTAssertEqual(windows.raised.count, raisedBefore, "nothing is brought forward while the layout scrolls")
        XCTAssertEqual(coordinator.focusedZoneID, screenZone)

        coordinator.isScrolling = false   // it has landed, and the screen's zone is in view
        coordinator.finishFocusBeyondTheEdge()
        XCTAssertEqual(windows.raised.last, 1, "only the last zone asked for gets the focus")
    }

    func testTheFocusGoesOnToAZoneBeyondTheEdgeAndTheFrameWaitsForItToComeIntoView() {
        let screenZone = UUID(), beyond = UUID()
        let here = CGRect(x: 0, y: 0, width: 1000, height: 800), there = CGRect(x: 1000, y: 0, width: 1000, height: 800)
        coordinator.apply(plan: [screenZone: PlannedZone(rect: here), beyond: PlannedZone(rect: there, frame: CGRect(x: 999, y: 0, width: 1000, height: 800), isParked: true)])
        coordinator.snap(.fake(1), into: screenZone)
        coordinator.snap(.fake(2), into: beyond)
        windows.focused = .fake(1)
        var flashed: [CGRect] = []
        var asked: [UUID] = []
        coordinator.flashZone = { flashed.append($0) }
        let standsAt = CGRect(x: 0, y: 0, width: 1000, height: 800)
        coordinator.onReachBeyondTheEdge = { zone, told in asked.append(zone); told(standsAt); return true }

        coordinator.focusZone(toward: .left)
        XCTAssertTrue(asked.isEmpty, "nothing lies beyond the left edge")
        settings.values.zoneNavigationBeyondEdges = false
        coordinator.focusZone(toward: .right)
        XCTAssertTrue(asked.isEmpty, "switched off: the focus stays on the screen")
        settings.values.zoneNavigationBeyondEdges = true
        coordinator.focusZone(toward: .right)
        XCTAssertEqual(asked, [beyond], "the layout is asked to scroll to it")
        XCTAssertTrue(windows.raised.isEmpty || windows.raised.last != 2, "the window waits for the scroll to be over")
        XCTAssertEqual(flashed, [standsAt], "the frame shows at once where the zone will stand")

        coordinator.finishFocusBeyondTheEdge()
        XCTAssertEqual(flashed.count, 1, "still out of sight: a later scroll may bring it")
        let landed = [screenZone: PlannedZone(rect: CGRect(x: -1000, y: 0, width: 1000, height: 800)), beyond: PlannedZone(rect: here)]
        coordinator.showFocusFrame(in: landed)
        XCTAssertEqual(flashed.count, 1, "the frame went ahead: not shown again when the glide is over")
        coordinator.apply(plan: landed)
        coordinator.finishFocusBeyondTheEdge()
        XCTAssertEqual(windows.raised.last, 2)
        XCTAssertEqual(flashed.count, 1, "once: the window comes forward without a second frame")
        coordinator.finishFocusBeyondTheEdge()
        XCTAssertEqual(windows.raised.filter { $0 == 2 }.count, 1)
    }

    func testSnapRemembersTheWindowAndUnsnapForgetsIt() {
        let zone = UUID()
        coordinator.apply(zones: [zone: CGRect(x: 0, y: 0, width: 100, height: 100)])
        coordinator.snap(.fake(1), into: zone)
        XCTAssertEqual(memory.records.count, 1)
        XCTAssertEqual(coordinator.stacks[zone]?.tabs.map(\.id), [1])

        coordinator.unsnap(window: 1)
        XCTAssertTrue(memory.records.isEmpty)
        XCTAssertEqual(coordinator.stacks[zone]?.tabs.count, 0)
    }

    func testLeavingTheStackRaisesNoOtherWindow() {
        let zone = UUID()
        coordinator.apply(zones: [zone: CGRect(x: 0, y: 0, width: 100, height: 100)])
        coordinator.snap(.fake(1), into: zone)
        coordinator.snap(.fake(2), into: zone)
        let raisedBefore = windows.raised.count

        coordinator.release(window: 2)

        XCTAssertEqual(windows.raised.count, raisedBefore)
        XCTAssertEqual(coordinator.stacks[zone]?.tabs.map(\.id), [1])
    }

    func testAPillClickSlidesTheChosenWindowAndTheRealOneComesToTheFront() {
        let snapshots = FakeWindowSnapshots(), stage = FakeSlideStage()
        snapshots.images = [1: FakeWindowSnapshots.picture(), 2: FakeWindowSnapshots.picture()]
        coordinator.carousel = ZoneCarousel(snapshots: snapshots, stage: stage, reduceMotion: { false }, background: { $0() })
        let zone = UUID()
        coordinator.apply(zones: [zone: CGRect(x: 0, y: 0, width: 100, height: 100)])
        coordinator.snap(.fake(1), into: zone)
        coordinator.snap(.fake(2), into: zone)
        let stack = coordinator.stacks[zone]!
        XCTAssertEqual(stack.activeID, 2)

        coordinator.slideSelect(1, in: stack)

        XCTAssertEqual(stage.slides.count, 1)
        XCTAssertEqual(stage.slides.first?.forward, false, "window 1 comes before window 2 in the pill, so it comes in from the left")
        XCTAssertEqual(stack.activeID, 1)
        XCTAssertEqual(windows.raised.last, 1)
        XCTAssertTrue(coordinator.isSliding)

        coordinator.slideSelect(2, in: stack)
        XCTAssertEqual(stack.activeID, 1, "a click during the slide is ignored")
        stage.end()
        XCTAssertFalse(coordinator.isSliding)
    }

    func testTheShortcutMovesTheFocusedWindowsZoneOnAndBackAndNotPastTheEnds() {
        let snapshots = FakeWindowSnapshots(), stage = FakeSlideStage()
        snapshots.images = [1: FakeWindowSnapshots.picture(), 2: FakeWindowSnapshots.picture(), 3: FakeWindowSnapshots.picture()]
        coordinator.carousel = ZoneCarousel(snapshots: snapshots, stage: stage, reduceMotion: { false }, background: { $0() })
        let zone = UUID()
        coordinator.apply(zones: [zone: CGRect(x: 0, y: 0, width: 100, height: 100)])
        [1, 2, 3].forEach { coordinator.snap(.fake($0), into: zone) }
        let stack = coordinator.stacks[zone]!
        let begun = stage.scrubBegun.count

        windows.focused = .fake(3)
        coordinator.cycleFocusedZone(reverse: false)
        XCTAssertEqual(stack.activeID, 3, "after the last there is nothing: it does not go round to the first")
        windows.focused = .fake(1)
        coordinator.cycleFocusedZone(reverse: true)
        XCTAssertEqual(stack.activeID, 1, "nor before the first (the window in focus is the one in front)")
        XCTAssertEqual(stage.scrubBegun.count, begun, "and nothing is photographed for it")

        coordinator.cycleFocusedZone(reverse: false)
        XCTAssertEqual(stage.scrubEnded, [1], "in between the pictures go on one window, the way a turn of the wheel over the pill does")
        XCTAssertEqual(stack.activeID, 2)
        windows.focused = .fake(2)
        coordinator.cycleFocusedZone(reverse: true)
        XCTAssertEqual(stage.scrubEnded, [1, -1])
        XCTAssertEqual(stack.activeID, 1)

        windows.focused = .fake(9)   // not in any zone
        coordinator.cycleFocusedZone(reverse: false)
        XCTAssertEqual(stack.activeID, 1)
    }

    func testPressingTheShortcutAgainWhileThePicturesGlideGoesOnFromWhereTheyAreInEitherDirection() {
        let snapshots = FakeWindowSnapshots(), stage = FakeSlideStage()
        snapshots.images = Dictionary(uniqueKeysWithValues: (1...4).map { (CGWindowID($0), FakeWindowSnapshots.picture()) })
        coordinator.carousel = ZoneCarousel(snapshots: snapshots, stage: stage, reduceMotion: { false }, background: { $0() })
        let zone = UUID()
        coordinator.apply(zones: [zone: CGRect(x: 0, y: 0, width: 100, height: 100)])
        [1, 2, 3, 4].forEach { coordinator.snap(.fake($0), into: zone) }
        let stack = coordinator.stacks[zone]!
        stage.end()
        stage.holdsGlide = true

        windows.focused = .fake(1)
        stack.activeID = 1
        coordinator.cycleFocusedZone(reverse: false)
        XCTAssertEqual(stack.activeID, 2)
        stage.glidingAt = 60
        coordinator.cycleFocusedZone(reverse: false)   // the focus is still on window 1 until the real window comes forward
        XCTAssertEqual(stack.activeID, 3, "the second press goes on from the window the pictures go to")
        XCTAssertEqual(stage.catches, 1, "no waiting for them to settle")
        XCTAssertEqual(stage.scrubEnded, [1, 1])

        coordinator.cycleFocusedZone(reverse: true)
        XCTAssertEqual(stack.activeID, 2, "and the other way is not ignored while they glide")
        XCTAssertEqual(stage.scrubEnded, [1, 1, -1])
    }

    func testWithStageManagerADroppedWindowIsOnlyPlacedAndNothingElseHappens() {
        let zone = UUID(), rect = CGRect(x: 0, y: 0, width: 100, height: 100)
        coordinator.apply(zones: [zone: rect])
        coordinator.snap(.fake(1), into: zone)   // held and remembered before Stage Manager was switched on
        let before = memory.records

        coordinator.placementOnly = { true }
        windows.setFrame(CGRect(x: 300, y: 300, width: 50, height: 50), of: .fake(2))
        coordinator.snap(.fake(2), into: zone)
        XCTAssertEqual(windows.frames[2], rect, "sized and placed by the zone")
        XCTAssertEqual(memory.records, before, "nothing is remembered")
        XCTAssertEqual(coordinator.stacks[zone]?.tabs.map(\.id), [1], "nothing is held")

        coordinator.unsnap(window: 1)
        XCTAssertEqual(memory.records, before, "and nothing remembered is changed")
        windows.focused = .fake(1)
        coordinator.cycleFocusedZone(reverse: false)
        XCTAssertEqual(coordinator.stacks[zone]?.activeID, 1)
        windows.setFrame(.zero, of: .fake(1))
        coordinator.apply(zones: [zone: rect])
        XCTAssertEqual(windows.frames[1], .zero, "held windows are not moved either")
    }

    func testAnIgnoredAppIsNeverSnappedAndLetGoWhenItJoinsTheList() {
        let apps = FakeApps()
        apps.apps = [AppInfo(pid: 100, bundleID: "free", name: "Free"), AppInfo(pid: 200, bundleID: "other", name: "Other")]
        let settings = AppSettings(storage: StubSettingsStorage())
        let coordinator = StackCoordinator(windows: windows, memory: memory, settings: settings, apps: apps)
        let zone = UUID()
        coordinator.apply(zones: [zone: CGRect(x: 0, y: 0, width: 100, height: 100)])
        coordinator.snap(.fake(1, pid: 100), into: zone)
        coordinator.snap(.fake(2, pid: 200), into: zone)

        settings.values.ignoredApps = ["free"]
        coordinator.releaseIgnoredApps()

        XCTAssertEqual(coordinator.stacks[zone]?.tabs.map(\.id), [2], "its window leaves the zone")
        coordinator.snap(.fake(3, pid: 100), into: zone)
        XCTAssertEqual(coordinator.stacks[zone]?.tabs.map(\.id), [2], "and a new one is not taken in")
    }

    func testAWindowPulledOutOfItsZoneGetsItsOwnSizeBack() {
        let zone = UUID()
        coordinator.apply(zones: [zone: CGRect(x: 0, y: 0, width: 100, height: 100)])
        windows.setFrame(CGRect(x: 300, y: 300, width: 600, height: 400), of: .fake(1))

        coordinator.snap(.fake(1), into: zone)
        XCTAssertEqual(windows.frames[1]?.size, CGSize(width: 100, height: 100), "the zone sized it")

        // Dragged away: the window now stands at 500, 200 and the pointer holds it a quarter of the way along.
        windows.setFrameDirectly(CGRect(x: 500, y: 200, width: 100, height: 100), of: 1)
        coordinator.takeOut(.fake(1), grabbedAt: CGPoint(x: 525, y: 210))

        XCTAssertEqual(windows.frames[1], CGRect(x: 375, y: 200, width: 600, height: 400), "its own size, still held a quarter along")
        XCTAssertNil(coordinator.stack(containing: 1))
    }

    func testTheSizeStaysTheZonesWhenTheSettingIsOff() {
        let settings = AppSettings(storage: StubSettingsStorage())
        settings.values.restoreSizeOnLeave = false
        let coordinator = StackCoordinator(windows: windows, memory: memory, settings: settings, apps: FakeApps())
        let zone = UUID()
        coordinator.apply(zones: [zone: CGRect(x: 0, y: 0, width: 100, height: 100)])
        windows.setFrame(CGRect(x: 300, y: 300, width: 600, height: 400), of: .fake(1))
        coordinator.snap(.fake(1), into: zone)

        coordinator.takeOut(.fake(1), grabbedAt: CGPoint(x: 525, y: 210))

        XCTAssertEqual(windows.frames[1]?.size, CGSize(width: 100, height: 100))
        XCTAssertNil(coordinator.stack(containing: 1), "it still leaves the zone")
    }

    func testScrollingWithTheKeysHeldStepsThroughTheZoneUnderThePointerWithoutGoingRound() {
        let zone = UUID(), other = UUID()
        coordinator.apply(zones: [zone: CGRect(x: 0, y: 0, width: 100, height: 100), other: CGRect(x: 100, y: 0, width: 100, height: 100)])
        coordinator.snap(.fake(1), into: zone)
        coordinator.snap(.fake(2), into: zone)
        coordinator.snap(.fake(3), into: other)
        coordinator.stacks[zone]?.activeID = 1

        coordinator.stepWindowScrub(at: CGPoint(x: 50, y: 50), by: 1)
        XCTAssertEqual(coordinator.stacks[zone]?.activeID, 2, "one step on, in the zone under the pointer")

        coordinator.stepWindowScrub(at: CGPoint(x: 50, y: 50), by: 1)
        XCTAssertEqual(coordinator.stacks[zone]?.activeID, 2, "the end: no going round")
        XCTAssertEqual(coordinator.stacks[other]?.activeID, 3, "the other zone is left alone")

        coordinator.stepWindowScrub(at: CGPoint(x: 50, y: 50), by: -1)
        XCTAssertEqual(coordinator.stacks[zone]?.activeID, 1, "a step back")
    }

    func testWithoutACarouselThePillClickJustSelects() {
        let zone = UUID()
        coordinator.apply(zones: [zone: CGRect(x: 0, y: 0, width: 100, height: 100)])
        coordinator.snap(.fake(1), into: zone)
        coordinator.snap(.fake(2), into: zone)
        coordinator.slideSelect(1, in: coordinator.stacks[zone]!)
        XCTAssertEqual(coordinator.stacks[zone]?.activeID, 1)
    }

    func testThePillMovesAtTheClickWhileTheRealWindowWaitsForThePictures() {
        let snapshots = FakeWindowSnapshots(), stage = FakeSlideStage()
        snapshots.images = [1: FakeWindowSnapshots.picture(), 2: FakeWindowSnapshots.picture()]
        stage.coversAtOnce = false   // the pictures are not on screen yet
        coordinator.carousel = ZoneCarousel(snapshots: snapshots, stage: stage, reduceMotion: { false }, background: { $0() })
        let zone = UUID()
        coordinator.apply(zones: [zone: CGRect(x: 0, y: 0, width: 100, height: 100)])
        coordinator.snap(.fake(1), into: zone)
        coordinator.snap(.fake(2), into: zone)
        let stack = coordinator.stacks[zone]!

        coordinator.slideSelect(1, in: stack)
        XCTAssertEqual(stack.activeID, 1, "the pill follows at once")
        XCTAssertEqual(windows.raised.last, 2, "while the real window waits for the pictures")

        stage.cover()
        XCTAssertEqual(windows.raised.last, 1)
    }

    // MARK: A swipe the fingers lead

    private func scrubSetUp(reduceMotion: Bool = false, windowCount: Int = 3) -> (stage: FakeSlideStage, snapshots: FakeWindowSnapshots, zone: UUID) {
        let snapshots = FakeWindowSnapshots(), stage = FakeSlideStage()
        snapshots.images = Dictionary(uniqueKeysWithValues: (1...windowCount).map { (CGWindowID($0), FakeWindowSnapshots.picture()) })
        coordinator.carousel = ZoneCarousel(snapshots: snapshots, stage: stage, reduceMotion: { reduceMotion }, background: { $0() })
        let zone = UUID()
        coordinator.apply(zones: [zone: CGRect(x: 0, y: 0, width: 400, height: 300)])
        for id in 1...windowCount { coordinator.snap(.fake(CGWindowID(id)), into: zone) }
        coordinator.stacks[zone]?.activeID = 2
        stage.end()   // the slides of the snaps
        return (stage, snapshots, zone)
    }

    func testTheFingersLeadTheSlideAndTheWideSwipeLetsGoOnTheNextWindow() {
        let (stage, _, zone) = scrubSetUp()

        coordinator.beginWindowScrub(at: CGPoint(x: 200, y: 150))
        XCTAssertEqual(stage.scrubBegun.count, 1)
        XCTAssertTrue(stage.scrubBegun.first?.count == 3 && stage.scrubBegun.first?.current == 1, "every window of the zone, the one in front marked")
        XCTAssertTrue(coordinator.isSliding, "nothing else slides while the fingers lead")

        coordinator.moveWindowScrub(by: -80, at: 0)
        coordinator.moveWindowScrub(by: -80, at: 0.3)
        XCTAssertEqual(stage.scrubOffsets.last, -160, "the pictures follow the fingers")

        coordinator.endWindowScrub()
        XCTAssertEqual(stage.scrubEnded, [1])
        XCTAssertEqual(coordinator.stacks[zone]?.activeID, 3, "the pill moves to the chosen window")
        XCTAssertEqual(windows.raised.last, 3, "and the real window comes forward under the pictures")
        XCTAssertFalse(coordinator.isSliding)
    }

    func testAShortSlowSwipeGoesBackToTheWindowItCameFrom() {
        let (stage, _, zone) = scrubSetUp()

        coordinator.beginWindowScrub(at: CGPoint(x: 200, y: 150))
        coordinator.moveWindowScrub(by: 30, at: 0)
        coordinator.moveWindowScrub(by: 10, at: 0.5)
        coordinator.endWindowScrub()

        XCTAssertEqual(stage.scrubEnded, [0])
        XCTAssertEqual(coordinator.stacks[zone]?.activeID, 2)
    }

    func testOneSwipeCanPassSeveralWindows() {
        let (stage, _, zone) = scrubSetUp(windowCount: 6)
        coordinator.stacks[zone]?.activeID = 1

        coordinator.beginWindowScrub(at: CGPoint(x: 200, y: 150))
        for t in 0 ..< 4 { coordinator.moveWindowScrub(by: -300, at: Double(t) * 0.5) }   // 1200 pt of a 400 pt zone
        XCTAssertEqual(stage.scrubOffsets.last, -1200, "the fingers are not held to the next window")
        coordinator.endWindowScrub()

        XCTAssertEqual(stage.scrubEnded, [3])
        XCTAssertEqual(coordinator.stacks[zone]?.activeID, 4)
    }

    func testTheSwipeIsNotLedPastTheFirstOrTheLastWindow() {
        let (stage, _, zone) = scrubSetUp()   // three windows of 400 pt, the middle one in front

        coordinator.beginWindowScrub(at: CGPoint(x: 200, y: 150))
        coordinator.moveWindowScrub(by: 900, at: 0)
        XCTAssertEqual(stage.scrubOffsets.last, 400, "the first window's left edge is where the pictures stop")
        coordinator.moveWindowScrub(by: -2400, at: 0.5)
        XCTAssertEqual(stage.scrubOffsets.last, -400, "and the last window's")
        coordinator.endWindowScrub()
        XCTAssertEqual(coordinator.stacks[zone]?.activeID, 3)

        coordinator.beginWindowScrub(at: CGPoint(x: 200, y: 150))
        coordinator.moveWindowScrub(by: -500, at: 0)
        XCTAssertEqual(stage.scrubOffsets.last, 0, "the last window is in front: nothing more that way")
        coordinator.moveWindowScrub(by: 60, at: 0.2)
        XCTAssertEqual(stage.scrubOffsets.last, 60, "coming back is followed at once")
        coordinator.endWindowScrub()
    }

    func testFingersThatComeDownWhileThePicturesGlideTakeThemOverWhereTheyAre() {
        let (stage, snapshots, zone) = scrubSetUp()
        stage.holdsGlide = true

        coordinator.beginWindowScrub(at: CGPoint(x: 200, y: 150))
        coordinator.moveWindowScrub(by: -300, at: 0)
        coordinator.endWindowScrub()
        XCTAssertEqual(stage.scrubEnded, [1])
        XCTAssertEqual(coordinator.stacks[zone]?.activeID, 3)
        XCTAssertTrue(coordinator.isSliding, "the pictures still glide")

        // New fingers, while they glide: no new photographs and no new start, the pictures are taken over 120 pt short of their window.
        let photographs = snapshots.requests
        stage.glidingAt = 120
        coordinator.beginWindowScrub(at: CGPoint(x: 200, y: 150))
        XCTAssertEqual(stage.catches, 1)
        XCTAssertEqual(stage.scrubBegun.count, 1, "the pictures are the ones that were gliding")
        XCTAssertEqual(snapshots.requests, photographs)
        XCTAssertEqual(stage.scrubOffsets.last, 120, "they stand where they were")
        coordinator.moveWindowScrub(by: -50, at: 1.0)
        XCTAssertEqual(stage.scrubOffsets.last, 70, "and follow the fingers from there")

        coordinator.moveWindowScrub(by: -300, at: 1.2)
        XCTAssertEqual(stage.scrubOffsets.last, 0, "the last window still is the end")
        coordinator.endWindowScrub()
    }

    func testAChoiceTheRunningSlideCannotTakeOnWaitsAndIsDoneWhenItIsOver() {
        let (stage, _, zone) = scrubSetUp()   // three windows, the middle one in front
        let stack = coordinator.stacks[zone]!
        let before = stage.slides.count

        coordinator.slideSelect(3, in: stack)   // a click on the pill: a slide, which the pictures of a swipe cannot take over
        XCTAssertEqual(stage.slides.suffix(from: before).map(\.forward), [true])
        coordinator.stepWindowScrub(in: stack, by: -1)   // the other way, while the slide runs
        XCTAssertEqual(stage.slides.count, before + 1, "not now")
        XCTAssertEqual(coordinator.stacks[zone]?.activeID, 3)

        stage.end()
        XCTAssertEqual(stage.slides.suffix(from: before).map(\.forward), [true, false], "but it is not lost: it is done as soon as the slide is over")
        XCTAssertEqual(coordinator.stacks[zone]?.activeID, 2)
    }

    func testAChoiceThatComesWhileThePicturesAreStillBeingTakenCarriesTheSlideOnWhenTheyAreThere() {
        let (stage, snapshots, zone) = scrubSetUp(windowCount: 6)
        let stack = coordinator.stacks[zone]!
        snapshots.answersAtOnce = false

        coordinator.slideSelect(3, in: stack)   // 2 to 3: the photographs are on their way
        coordinator.stepWindowScrub(in: stack, by: 1)   // 3 to 4: the slide is not on the stage to be carried on yet
        XCTAssertEqual(coordinator.stacks[zone]?.activeID, 3)
        XCTAssertTrue(stage.extensions.isEmpty)

        snapshots.answer()   // the slide goes on the stage; the waiting choice carries it on, and its picture is asked for
        XCTAssertEqual(coordinator.stacks[zone]?.activeID, 4)
        snapshots.answer()
        XCTAssertEqual(stage.extensions, [true], "one more window along the same slide")
    }

    func testOnlyAFewChoicesWaitSoThatAKeyHeldDownDoesNotGoOnAfterItIsLetGo() {
        let (stage, _, zone) = scrubSetUp(windowCount: 8)
        let stack = coordinator.stacks[zone]!
        stack.activeID = 5

        coordinator.slideSelect(6, in: stack)   // 5 to 6, and the slide runs
        for _ in 0 ..< 6 { coordinator.stepWindowScrub(in: stack, by: -1) }   // the other way: none can be taken now
        XCTAssertEqual(coordinator.stacks[zone]?.activeID, 6)

        stage.end()
        XCTAssertEqual(coordinator.stacks[zone]?.activeID, 3, "three of the six were kept, one window back for each, not all six")
    }

    // MARK: Scrolling over a pill

    func testTwoFingersOverAPillLeadThePicturesOverAsManyWindowsAsTheyGoAndLetGoOnTheNearest() {
        let (stage, _, zone) = scrubSetUp(windowCount: 6)   // the second of six in front, 400 pt wide
        let stack = coordinator.stacks[zone]!
        let router = PillScrollRouter(coordinator: coordinator, gain: { 1 })

        router.trackpad(over: stack, horizontal: -300, vertical: 5, began: true, finished: false, at: 0)
        router.trackpad(over: stack, horizontal: -300, vertical: 0, began: false, finished: false, at: 0.5)
        router.trackpad(over: stack, horizontal: -300, vertical: 0, began: false, finished: false, at: 1.0)
        XCTAssertEqual(stage.scrubOffsets.last, -900, "no step by step: the pictures follow the fingers all the way")

        router.trackpad(over: stack, horizontal: 0, vertical: 0, began: false, finished: true, at: 1.1)
        XCTAssertEqual(stage.scrubEnded, [2], "and come to rest on the window they are nearest")
        XCTAssertEqual(stack.activeID, 4)
    }

    func testAnUpwardSwipeOverAPillGoesOnToTheNextWindowsToo() {
        let (stage, _, zone) = scrubSetUp(windowCount: 6)
        let stack = coordinator.stacks[zone]!
        let router = PillScrollRouter(coordinator: coordinator, gain: { 1 })

        router.trackpad(over: stack, horizontal: 1, vertical: -60, began: true, finished: false, at: 0)
        router.trackpad(over: stack, horizontal: 0, vertical: -300, began: false, finished: false, at: 0.4)
        router.trackpad(over: stack, horizontal: 0, vertical: 0, began: false, finished: true, at: 0.5)
        XCTAssertEqual(stage.scrubEnded.count, 1)
        XCTAssertGreaterThan(stage.scrubEnded[0], 0, "fingers up: on to the next windows")
    }

    func testANewSwipeOverAPillTakesTheGlidingPicturesOverAndGoesOnFromThere() {
        let (stage, _, zone) = scrubSetUp(windowCount: 6)
        let stack = coordinator.stacks[zone]!
        stage.holdsGlide = true
        let router = PillScrollRouter(coordinator: coordinator, gain: { 1 })

        router.trackpad(over: stack, horizontal: -450, vertical: 0, began: true, finished: false, at: 0)
        router.trackpad(over: stack, horizontal: 0, vertical: 0, began: false, finished: true, at: 0.5)   // 450 pt: one window on, gliding
        XCTAssertEqual(stage.scrubEnded, [1])

        stage.glidingAt = 150   // the pictures are 150 pt short of it
        router.trackpad(over: stack, horizontal: -100, vertical: 0, began: true, finished: false, at: 1)
        XCTAssertEqual(stage.catches, 1, "no waiting for the glide to end")
        XCTAssertEqual(stage.scrubOffsets.last, 50, "they follow the new fingers from where they were")
        router.trackpad(over: stack, horizontal: 0, vertical: 0, began: false, finished: true, at: 1.5)
        XCTAssertEqual(stage.scrubEnded.count, 2)
    }

    func testEachTurnOfAWheelOverAPillIsAStepThroughThePicturesEvenWhileTheyGlide() {
        let (stage, _, zone) = scrubSetUp(windowCount: 6)
        let stack = coordinator.stacks[zone]!
        stage.holdsGlide = true
        let router = PillScrollRouter(coordinator: coordinator, gain: { 1 })

        router.wheel(over: stack, delta: -1)   // toward you: the next window
        XCTAssertEqual(stage.scrubEnded, [1])
        XCTAssertEqual(stack.activeID, 3)

        stage.glidingAt = 120
        router.wheel(over: stack, delta: -1)   // the pictures are still on their way: one more, from where they are
        XCTAssertEqual(stage.catches, 1)
        XCTAssertEqual(stage.scrubEnded, [1, 1])
        XCTAssertEqual(stack.activeID, 4)

        router.wheel(over: stack, delta: 2)   // away from you: back, also while they glide
        XCTAssertEqual(stage.scrubEnded, [1, 1, -1])
        XCTAssertEqual(stack.activeID, 3)
    }

    func testTurnsThatComeWhileThePicturesAreBeingTakenAddUp() {
        let (stage, snapshots, zone) = scrubSetUp(windowCount: 6)
        let stack = coordinator.stacks[zone]!
        snapshots.answersAtOnce = false
        let router = PillScrollRouter(coordinator: coordinator, gain: { 1 })

        router.wheel(over: stack, delta: -1)
        router.wheel(over: stack, delta: -1)
        router.wheel(over: stack, delta: -1)
        XCTAssertTrue(stage.scrubEnded.isEmpty, "the pictures are not there yet")

        snapshots.answer()
        XCTAssertEqual(stage.scrubEnded, [3], "all three turns, as one glide")
        XCTAssertEqual(stack.activeID, 5)
    }

    func testAWheelOverAPillAlsoStepsWhenThePicturesCannotMoveBecauseAnotherSlideRuns() {
        let (stage, _, zone) = scrubSetUp(windowCount: 6)
        let stack = coordinator.stacks[zone]!
        let router = PillScrollRouter(coordinator: coordinator, gain: { 1 })
        let before = stage.slides.count

        coordinator.slideSelect(3, in: stack)   // a click on the pill: a slide
        router.wheel(over: stack, delta: 1)   // back, while it runs: it waits
        XCTAssertEqual(stage.slides.count, before + 1)
        stage.end()
        XCTAssertEqual(stage.slides.suffix(from: before).map(\.forward), [true, false], "and is not lost")
        XCTAssertEqual(stack.activeID, 2)
    }

    func testTheEndMayComeBeforeThePicturesAndIsActedOnWhenTheyArrive() {
        let (stage, snapshots, zone) = scrubSetUp()
        snapshots.answersAtOnce = false

        coordinator.beginWindowScrub(at: CGPoint(x: 200, y: 150))
        coordinator.moveWindowScrub(by: 150, at: 0)
        coordinator.endWindowScrub()
        XCTAssertTrue(stage.scrubEnded.isEmpty, "the pictures are not there yet")

        snapshots.answer()
        XCTAssertEqual(stage.scrubOffsets.last, 150, "they start where the fingers already are")
        XCTAssertEqual(stage.scrubEnded, [-1])
        XCTAssertEqual(coordinator.stacks[zone]?.activeID, 1)
    }

    func testAWindowWithoutAPictureIsLeftOutOfTheSwipe() {
        let (stage, snapshots, zone) = scrubSetUp(windowCount: 4)
        snapshots.images[3] = nil   // could not be photographed
        coordinator.stacks[zone]?.activeID = 2

        coordinator.beginWindowScrub(at: CGPoint(x: 200, y: 150))
        XCTAssertEqual(stage.scrubBegun.first?.count, 3)
        coordinator.moveWindowScrub(by: -200, at: 0)
        coordinator.endWindowScrub()

        XCTAssertEqual(coordinator.stacks[zone]?.activeID, 4, "the next one the swipe could show")
    }

    func testWithoutPicturesTheSwipeJustBringsTheWindowForward() {
        let (stage, _, zone) = scrubSetUp(reduceMotion: true)

        coordinator.beginWindowScrub(at: CGPoint(x: 200, y: 150))
        coordinator.moveWindowScrub(by: -200, at: 0)
        coordinator.endWindowScrub()

        XCTAssertTrue(stage.scrubBegun.isEmpty)
        XCTAssertEqual(coordinator.stacks[zone]?.activeID, 3)
        XCTAssertEqual(windows.raised.last, 3)
    }
}
