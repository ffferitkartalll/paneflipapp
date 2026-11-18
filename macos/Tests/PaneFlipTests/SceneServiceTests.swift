import XCTest
import PaneFlipCore

final class SceneServiceTests: XCTestCase {
    private let area = CGRect(x: 0, y: 0, width: 1000, height: 600)
    private var repository: LayoutRepository!
    private var scenes: SceneRepository!
    private var memory: StackMemory!
    private var service: SceneService!
    private var desk = DeskArrangement()
    private var fakeLayouts: FakeLayouts!
    private var fakeScreens: FakeScreens!

    private func info(_ key: String) -> ScreenInfo { ScreenInfo(key: key, name: key, size: area.size, cocoaFrame: area, cocoaVisibleFrame: area, axVisible: area) }

    override func setUp() {
        repository = LayoutRepository(store: MemoryDocumentStore())
        scenes = SceneRepository(store: MemoryDocumentStore())
        memory = StackMemory(store: MemoryDocumentStore())
        fakeLayouts = FakeLayouts(repository: repository)
        fakeScreens = FakeScreens()
        let coordinator = StackCoordinator(windows: FakeWindowSystem(), memory: memory, settings: AppSettings(storage: StubSettingsStorage()), apps: FakeApps())
        service = SceneService(scenes: scenes, repository: repository, layouts: fakeLayouts, memory: memory, coordinator: coordinator, loose: LooseWindows(windows: FakeWindowSystem(), screens: fakeScreens, repository: repository, memory: memory, coordinator: coordinator), screens: fakeScreens, arrangement: { [unowned self] in self.desk })
    }

    func testTheWindowsOfAnUnpluggedDisplayGoToTheOtherOneAndComeBackWhenItIsPluggedIn() {
        let a = repository.addLayout(for: "A|d1", named: "", preset: .custom(rows: 1, columns: 2))
        let b = repository.addStandardLayout(for: "B|d1", named: "")
        let both = [info("A|d1"), info("B|d1")]
        service.displaysDidChange(on: both)
        let slot = memory.remember(zoneID: b.root.leafIDs[0], bundleID: "app", title: "")

        service.displaysDidChange(on: [info("A|d1")])
        XCTAssertTrue(a.root.leafIDs.contains(memory.records[slot].zoneID), "it is on the remaining display now")

        service.displaysDidChange(on: both)
        XCTAssertEqual(memory.records[slot].zoneID, b.root.leafIDs[0], "and back where it was")
    }

    func testTheSceneInUseNamesWhereTheWindowsGo() {
        let a = repository.addLayout(for: "A|d1", named: "", preset: .custom(rows: 1, columns: 2))
        let b = repository.addStandardLayout(for: "B|d1", named: "")
        service.displaysDidChange(on: [info("A|d1"), info("B|d1")])
        let scene = scenes.add()
        service.setMoves(sceneID: scene.id, zone: b.root.leafIDs[0], to: [a.root.leafIDs[1]])
        service.select(id: scene.id)
        let slot = memory.remember(zoneID: b.root.leafIDs[0], bundleID: "app", title: "")

        service.displaysDidChange(on: [info("A|d1")])

        XCTAssertEqual(memory.records[slot].zoneID, a.root.leafIDs[1])
    }

    func testWithThreeDisplaysTheSceneChoosesTheRemainingOneAndEveryWindowComesBack() {
        let a = repository.addStandardLayout(for: "A|d1", named: "")
        let b = repository.addLayout(for: "B|d1", named: "", preset: .custom(rows: 1, columns: 2))
        let c = repository.addLayout(for: "C|d1", named: "", preset: .custom(rows: 1, columns: 2))
        let all = [info("A|d1"), info("B|d1"), info("C|d1")]
        let width = info("A|d1").deskSize.width
        desk = DeskArrangement(origins: ["A": CGPoint(x: 0, y: 0), "B": CGPoint(x: width, y: 0), "C": CGPoint(x: 3 * width, y: 0)])   // B stands next to A, C far off
        service.displaysDidChange(on: all)
        let scene = scenes.add()
        service.setMoves(sceneID: scene.id, zone: b.root.leafIDs[1], to: [c.root.leafIDs[0]])
        service.select(id: scene.id)
        memory.remember(zoneID: b.root.leafIDs[1], bundleID: "one", title: "")
        memory.remember(zoneID: b.root.leafIDs[0], bundleID: "two", title: "")
        memory.remember(zoneID: c.root.leafIDs[1], bundleID: "three", title: "")
        // Slots change places when they move: find each by its app.
        func zone(_ app: String) -> UUID? { memory.records.first { $0.bundleID == app }?.zoneID }

        service.displaysDidChange(on: [info("A|d1"), info("C|d1")])   // B is unplugged
        XCTAssertEqual(zone("one"), c.root.leafIDs[0], "the zone the scene names, on the other display")
        XCTAssertEqual(zone("two"), a.root.leafIDs[0], "the rest where they lie nearest on the desk: the display next to it")
        XCTAssertEqual(zone("three"), c.root.leafIDs[1], "a window of a display that stays is left alone")

        service.displaysDidChange(on: all)
        XCTAssertEqual(zone("one"), b.root.leafIDs[1])
        XCTAssertEqual(zone("two"), b.root.leafIDs[0])
        XCTAssertEqual(zone("three"), c.root.leafIDs[1])
    }

    func testTheWindowsTryTheZonesOfTheSceneInTheOrderItListsThem() {
        let a = repository.addLayout(for: "A|d1", named: "", preset: .custom(rows: 1, columns: 2))
        let b = repository.addStandardLayout(for: "B|d1", named: "")
        let c = repository.addStandardLayout(for: "C|d1", named: "")
        let all = [info("A|d1"), info("B|d1"), info("C|d1")]
        service.displaysDidChange(on: all)
        let scene = scenes.add()
        service.select(id: scene.id)
        memory.remember(zoneID: b.root.leafIDs[0], bundleID: "app", title: "")
        service.setMoves(sceneID: scene.id, zone: b.root.leafIDs[0], to: [c.root.leafIDs[0], a.root.leafIDs[1]])   // C first, then A

        service.displaysDidChange(on: [info("A|d1"), info("C|d1")])
        XCTAssertEqual(memory.records[0].zoneID, c.root.leafIDs[0], "the first it names that is connected")

        service.displaysDidChange(on: all)
        service.displaysDidChange(on: [info("A|d1")])   // C is away too
        XCTAssertEqual(memory.records[0].zoneID, a.root.leafIDs[1], "then the next")
    }

    func testWhatTheSceneDoesNotNameGoesToTheNearestZonesOnTheDesk() {
        let a = repository.addLayout(for: "A|d1", named: "", preset: .custom(rows: 1, columns: 2))
        let b = repository.addLayout(for: "B|d1", named: "", preset: .custom(rows: 1, columns: 2))
        let c = repository.addLayout(for: "C|d1", named: "", preset: .custom(rows: 1, columns: 4))
        let width = info("A|d1").deskSize.width
        desk = DeskArrangement(origins: ["A": CGPoint(x: 0, y: 0), "C": CGPoint(x: width, y: 0), "B": CGPoint(x: 2.5 * width, y: 0)])   // C stands next to A, B a little away
        service.displaysDidChange(on: [info("A|d1"), info("B|d1"), info("C|d1")])
        for (index, zone) in c.root.leafIDs.enumerated() { memory.remember(zoneID: zone, bundleID: "app\(index)", title: "") }

        service.displaysDidChange(on: [info("A|d1"), info("B|d1")])   // C is unplugged

        func zone(_ app: String) -> UUID? { memory.records.first { $0.bundleID == app }?.zoneID }
        XCTAssertTrue([zone("app0"), zone("app1"), zone("app2")].allSatisfy { a.root.leafIDs.contains($0!) }, "what lies nearest to the display next to it goes there")
        XCTAssertTrue(b.root.leafIDs.contains(zone("app3")!), "the zone farthest on goes to the other display")
    }

    func testALayoutChosenForADisplayInTheSceneInUseIsPutOnItAtOnce() {
        repository.addStandardLayout(for: "A|d1", named: "")
        let second = repository.addLayout(for: "A|d1", named: "", preset: .custom(rows: 1, columns: 2))
        fakeScreens.infos = [info("A|d1")]
        let scene = scenes.add()

        service.setLayout(sceneID: scene.id, display: "A", layoutID: second.id)
        XCTAssertTrue(fakeLayouts.activated.isEmpty, "a scene that is not in use leaves the displays alone")

        service.select(id: scene.id)
        fakeLayouts.reset()
        service.setLayout(sceneID: scene.id, display: "A", layoutID: second.id)
        XCTAssertEqual(fakeLayouts.activated, [second.id])
    }

    func testNothingMovesAtTheFirstLook() {
        let b = repository.addStandardLayout(for: "B|d1", named: "")
        let slot = memory.remember(zoneID: b.root.leafIDs[0], bundleID: "app", title: "")
        repository.addStandardLayout(for: "A|d1", named: "")
        service.displaysDidChange(on: [info("A|d1")])
        XCTAssertEqual(memory.records[slot].zoneID, b.root.leafIDs[0], "a display that was off before the app ever looked is not told apart from one never plugged in")
    }

    func testAnotherSceneLoadsItsOwnWindowsAndPutsItsLayoutsOnTheDisplaysWithoutMovingWindows() {
        let first = repository.addStandardLayout(for: "A|d1", named: "")
        fakeScreens.infos = [info("A|d1")]
        let scene = scenes.add()
        let slot = memory.remember(zoneID: first.root.leafIDs[0], bundleID: "app", title: "")
        memory.bind(slot: slot, toWindow: 4, title: "")
        service.setLayout(sceneID: scene.id, display: "A", layoutID: first.id)
        fakeLayouts.reset()

        service.select(id: scene.id)

        XCTAssertTrue(memory.records.isEmpty, "the scene has not been in use: nothing is remembered for it")
        XCTAssertEqual(fakeLayouts.activated, [first.id], "its layout is put on the display even though the same one is there")
        XCTAssertEqual(fakeLayouts.remapped, [false], "and no window is moved to the zones that lie where its were")
    }

    func testLooseWindowsAreStackedWithAPartOfEachShowingInsideTheZone() {
        let zone = CGRect(x: 100, y: 50, width: 400, height: 300)
        let frames = LooseWindows.cascade(in: zone, count: 3)
        XCTAssertEqual(frames.count, 3)
        XCTAssertEqual(frames[0].origin, zone.origin, "the one at the back is in the upper left corner")
        XCTAssertEqual(frames[1].origin.x - frames[0].origin.x, 24)
        XCTAssertEqual(frames[2].origin.y - frames[1].origin.y, 24, "each nearer the front is shifted down and to the right: the last is in front, in the lower right")
        XCTAssertTrue(frames.allSatisfy { zone.contains($0) }, "none leaves the zone")
        XCTAssertEqual(LooseWindows.cascade(in: zone, count: 1), [zone])
        XCTAssertGreaterThanOrEqual(LooseWindows.cascade(in: CGRect(x: 0, y: 0, width: 200, height: 100), count: 30)[0].height, 60)
    }

    func testALooseWindowIsDoneWhenItStandsInFrontOfTheOnesBeforeIt() {
        XCTAssertTrue(LooseWindows.stands(3, infrontOf: [1, 2], in: [9, 3, 2, 1, 8]), "other windows may stand in front of the whole stack")
        XCTAssertFalse(LooseWindows.stands(3, infrontOf: [1, 2], in: [2, 3, 1]), "behind one of them")
        XCTAssertTrue(LooseWindows.stands(3, infrontOf: [1, 2], in: [3, 1]), "one that is not on screen is no obstacle")
        XCTAssertFalse(LooseWindows.stands(3, infrontOf: [], in: [1, 2]), "not on screen itself: not there yet")
    }
}
