import XCTest
@testable import PaneFlipCore

final class SceneRepositoryTests: XCTestCase {
    func testThereIsAlwaysADefaultSceneThatIsNeitherRemovedNorRenamed() {
        let repository = SceneRepository(store: MemoryStore())
        let first = repository.scenes[0]
        XCTAssertTrue(repository.isDefault(first.id))
        repository.remove(first.id)
        repository.rename(first.id, to: "other")
        XCTAssertEqual(repository.scenes.map(\.id), [first.id])
        XCTAssertEqual(repository.scenes[0].name, "")
    }

    func testAnActiveSceneThatIsRemovedGivesWayToTheDefaultOne() {
        let repository = SceneRepository(store: MemoryStore())
        let added = repository.add()
        repository.select(added.id)
        XCTAssertEqual(repository.activeScene.id, added.id)
        repository.remove(added.id)
        XCTAssertEqual(repository.activeScene.id, repository.scenes[0].id)
    }

    func testResettingASceneForgetsItsLayoutsAndMovesButKeepsItsName() {
        let repository = SceneRepository(store: MemoryStore())
        let scene = repository.add()
        let layout = UUID(), zone = UUID(), target = UUID()
        repository.rename(scene.id, to: "work")
        repository.setLayout(layout, ofDisplay: "A", inScene: scene.id)
        repository.setMoves(ofZone: zone, to: [target], inScene: scene.id)
        XCTAssertEqual(repository.scenes[1].moves[zone], [target])

        repository.reset(scene.id)

        XCTAssertEqual(repository.scenes[1].name, "work")
        XCTAssertTrue(repository.scenes[1].layouts.isEmpty && repository.scenes[1].moves.isEmpty)
    }

    func testScenesAndTheDisplaysSeenSurviveARestart() {
        let store = MemoryStore()
        let repository = SceneRepository(store: store)
        let scene = repository.add()
        repository.select(scene.id)
        repository.seenDisplays = ["A", "B"]
        let again = SceneRepository(store: store)
        XCTAssertEqual(again.scenes.map(\.id), repository.scenes.map(\.id))
        XCTAssertEqual(again.activeScene.id, scene.id)
        XCTAssertEqual(again.seenDisplays, ["A", "B"])
    }

    func testTheWindowsOfZonesGoToTheZoneThatCoversTheSamePlaceOnTheOtherLayout() {
        let two = NamedLayout(name: "", root: LayoutPreset.custom(rows: 1, columns: 2).root)
        let one = NamedLayout.standard(name: "")
        let both = SceneMoves.automatic(from: two, to: one)
        XCTAssertEqual(Set(both.keys), Set(two.root.leafIDs))
        XCTAssertEqual(Set(both.values), Set(one.root.leafIDs), "two zones into one")
        let back = SceneMoves.automatic(from: one, to: two)
        XCTAssertEqual(back.count, 1)
        XCTAssertTrue(two.root.leafIDs.contains(back[one.root.leafIDs[0]]!))
    }

    func testASceneSavedWithOneDestinationForAZoneStillLoads() throws {
        let zone = UUID(), target = UUID()
        let old = String(decoding: try JSONEncoder().encode([zone: target]), as: UTF8.self)
        let json = "{\"id\":\"\(UUID())\",\"name\":\"\",\"layouts\":{},\"moves\":\(old)}"
        let scene = try JSONDecoder().decode(DisplayScene.self, from: Data(json.utf8))
        XCTAssertEqual(scene.moves[zone], [target])
    }

    func testTheDefaultZoneGoesToTheDefaultZoneAndTheOthersToOtherZones() {
        let source = NamedLayout(name: "", root: LayoutPreset.custom(rows: 1, columns: 3).root)
        var three = source
        three.defaultZoneID = three.root.leafIDs[1]
        var target = NamedLayout(name: "", root: LayoutPreset.custom(rows: 1, columns: 2).root)
        target.defaultZoneID = target.root.leafIDs[0]

        let map = SceneMoves.automatic(from: three, to: target)

        XCTAssertEqual(map[three.root.leafIDs[1]], target.root.leafIDs[0], "the default zone to the default zone")
        XCTAssertEqual(map[three.root.leafIDs[0]], target.root.leafIDs[1], "another zone to another zone, even where the default one covers it better")
        XCTAssertEqual(map[three.root.leafIDs[2]], target.root.leafIDs[1])
    }

    func testOtherZonesGoBeyondTheEdgeWhenTheTargetScreenHasOnlyItsDefaultZone() {
        let left = Overflow(width: 0.5, root: .leaf(UUID())), right = Overflow(width: 0.5, root: .leaf(UUID()))
        let target = NamedLayout(name: "", root: .leaf(UUID()), leading: [left], trailing: [right])
        var source = NamedLayout(name: "", root: LayoutPreset.custom(rows: 1, columns: 3).root)
        source.defaultZoneID = source.root.leafIDs[1]

        let map = SceneMoves.automatic(from: source, to: target)

        XCTAssertEqual(map[source.root.leafIDs[1]], target.root.leafIDs[0], "the default zone to the default zone")
        XCTAssertEqual(map[source.root.leafIDs[0]], left.root.leafIDs[0], "a zone left of its default one to the zone beyond the left edge")
        XCTAssertEqual(map[source.root.leafIDs[2]], right.root.leafIDs[0], "and one right of it to the zone beyond the right edge")
    }

    func testTheNearestDisplayOnTheDeskIsTriedFirstAndTheZonesGoToTheNearestZones() {
        // The unplugged display stands in the middle, one display to its left and one to its right, the left one a little farther.
        let source = NamedLayout(name: "", root: LayoutPreset.custom(rows: 1, columns: 4).root)
        let left = NamedLayout(name: "", root: LayoutPreset.custom(rows: 1, columns: 2).root)
        let right = NamedLayout(name: "", root: LayoutPreset.custom(rows: 1, columns: 2).root)
        let middle = CGRect(x: 1000, y: 0, width: 1000, height: 600)

        let placed = SceneMoves.onDesk(from: (middle, source), onto: [(CGRect(x: -100, y: 0, width: 1000, height: 600), left), (CGRect(x: 2000, y: 0, width: 1000, height: 600), right)])

        XCTAssertEqual(placed.order, [1, 0], "the one that touches it first")
        let zones = source.root.leafIDs   // the first is the default zone
        XCTAssertEqual(zones.map { placed.zones[$0]?.target }, [1, 0, 0, 1], "the default zone to the nearest display, then each zone to what lies nearest to it on the desk")
        XCTAssertEqual(placed.zones[zones[0]]?.zone, right.root.leafIDs[0], "its default zone")
        XCTAssertTrue(left.root.leafIDs.contains(placed.zones[zones[1]]!.zone))
        XCTAssertEqual(placed.zones[zones[3]]?.zone, right.root.leafIDs[1], "not its default zone, which is kept for the default zone")
    }

    func testTheDefaultZoneGoesToTheDefaultZoneOfTheNearestDisplay() {
        var source = NamedLayout(name: "", root: LayoutPreset.custom(rows: 1, columns: 3).root)
        source.defaultZoneID = source.root.leafIDs[0]
        let far = NamedLayout.standard(name: ""), near = NamedLayout.standard(name: "")
        let frame = CGRect(x: 0, y: 0, width: 1000, height: 600)

        let placed = SceneMoves.onDesk(from: (frame, source), onto: [(CGRect(x: 5000, y: 0, width: 1000, height: 600), far), (CGRect(x: 1000, y: 0, width: 1000, height: 600), near)])

        XCTAssertEqual(placed.order, [1, 0])
        XCTAssertEqual(placed.zones[source.root.leafIDs[0]]?.target, 1)
        XCTAssertEqual(placed.zones[source.root.leafIDs[0]]?.zone, near.root.leafIDs[0])
    }

    func testOneRemainingDisplayTakesEveryZoneAsBefore() {
        let source = NamedLayout(name: "", root: LayoutPreset.custom(rows: 1, columns: 3).root)
        let only = NamedLayout.standard(name: "")
        let frame = CGRect(x: 0, y: 0, width: 1000, height: 600)
        let placed = SceneMoves.onDesk(from: (frame, source), onto: [(CGRect(x: 1000, y: 0, width: 1000, height: 600), only)])
        XCTAssertEqual(placed.zones.mapValues(\.zone), SceneMoves.automatic(from: source, to: only))
    }
}
