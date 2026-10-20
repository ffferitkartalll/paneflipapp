import XCTest
import CoreGraphics
import PaneFlipCore

final class StackCoordinatorTests: XCTestCase {
    private var windows: FakeWindowSystem!
    private var memory: StackMemory!
    private var coordinator: StackCoordinator!

    override func setUp() {
        windows = FakeWindowSystem()
        memory = StackMemory(store: MemoryDocumentStore())
        coordinator = StackCoordinator(windows: windows, memory: memory,
                                       settings: AppSettings(storage: StubSettingsStorage()), apps: FakeApps())
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

    func testTheShortcutCyclesTheFocusedWindowsZoneAroundTheEnd() {
        let snapshots = FakeWindowSnapshots(), stage = FakeSlideStage()
        snapshots.images = [1: FakeWindowSnapshots.picture(), 2: FakeWindowSnapshots.picture(), 3: FakeWindowSnapshots.picture()]
        coordinator.carousel = ZoneCarousel(snapshots: snapshots, stage: stage, reduceMotion: { false }, background: { $0() })
        let zone = UUID()
        coordinator.apply(zones: [zone: CGRect(x: 0, y: 0, width: 100, height: 100)])
        [1, 2, 3].forEach { coordinator.snap(.fake($0), into: zone) }
        let stack = coordinator.stacks[zone]!

        windows.focused = .fake(3)
        coordinator.cycleFocusedZone(reverse: false)
        XCTAssertEqual(stack.activeID, 1, "after the last comes the first")
        XCTAssertEqual(stage.slides.last?.forward, true, "and it still slides the same way")
        stage.end()

        windows.focused = .fake(1)
        coordinator.cycleFocusedZone(reverse: true)
        XCTAssertEqual(stack.activeID, 3)
        XCTAssertEqual(stage.slides.last?.forward, false)
        stage.end()

        windows.focused = .fake(9)   // not in any zone
        coordinator.cycleFocusedZone(reverse: false)
        XCTAssertEqual(stack.activeID, 3)
    }

    func testPressingTheShortcutAgainDuringTheSlideCarriesItOnToTheNextWindow() {
        let snapshots = FakeWindowSnapshots(), stage = FakeSlideStage()
        snapshots.images = [1: FakeWindowSnapshots.picture(), 2: FakeWindowSnapshots.picture(), 3: FakeWindowSnapshots.picture()]
        coordinator.carousel = ZoneCarousel(snapshots: snapshots, stage: stage, reduceMotion: { false }, background: { $0() })
        let zone = UUID()
        coordinator.apply(zones: [zone: CGRect(x: 0, y: 0, width: 100, height: 100)])
        [1, 2, 3].forEach { coordinator.snap(.fake($0), into: zone) }
        let stack = coordinator.stacks[zone]!

        windows.focused = .fake(1)
        coordinator.cycleFocusedZone(reverse: false)
        XCTAssertEqual(stack.activeID, 2)
        coordinator.cycleFocusedZone(reverse: false)   // the focus is still on window 1 until the real window comes forward
        XCTAssertEqual(stack.activeID, 3, "the second press goes on from the window the slide goes to")
        XCTAssertEqual(stage.slides.count, 1)
        XCTAssertEqual(stage.extensions, [true])
        XCTAssertEqual(windows.raised.last, 3)

        coordinator.cycleFocusedZone(reverse: true)
        XCTAssertEqual(stack.activeID, 3, "the other way is ignored while the slide runs")
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

        coordinator.stepWindows(at: CGPoint(x: 50, y: 50), by: 1)
        XCTAssertEqual(coordinator.stacks[zone]?.activeID, 2, "one step on, in the zone under the pointer")

        coordinator.stepWindows(at: CGPoint(x: 50, y: 50), by: 1)
        XCTAssertEqual(coordinator.stacks[zone]?.activeID, 2, "the end: no going round")
        XCTAssertEqual(coordinator.stacks[other]?.activeID, 3, "the other zone is left alone")

        coordinator.stepWindows(at: CGPoint(x: 50, y: 50), by: -1)
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
