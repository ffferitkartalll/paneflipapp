import XCTest
@testable import PaneFlipCore

final class LayoutRepositoryDisplaysTests: XCTestCase {
    private func repository() -> LayoutRepository { LayoutRepository(store: MemoryStore()) }

    func testZonesOfDisplaysThatAreGoneAreTold() {
        let repository = repository()
        let kept = repository.addLayout(for: "A|d1")
        let gone = repository.addLayout(for: "B|d1")
        XCTAssertEqual(repository.zoneIDs(ofDisplaysNotIn: ["A"]), Set(gone.root.leafIDs))
        XCTAssertFalse(repository.zoneIDs(ofDisplaysNotIn: ["A"]).contains(kept.root.leafIDs[0]))
    }

    /// A document from before desktops were told apart by their position: one entry per "display|<space id>".
    private func oldRepository(_ keys: [String]) -> (LayoutRepository, [NamedLayout]) {
        let store = MemoryStore()
        let layouts = keys.map { _ in NamedLayout(name: "x", root: .leaf(UUID())) }
        store.save(Dictionary(uniqueKeysWithValues: zip(keys, layouts).map { ($0, ScreenLayouts(layouts: [$1], activeID: $1.id)) }),
                   named: "layouts-v2")
        return (LayoutRepository(store: store), layouts)
    }

    func testLayoutsMoveToANewKeyOnlyWhenItIsEmpty() {
        let (repository, layouts) = oldRepository(["A|757", "A|9"])
        repository.moveScreen(from: "A|757", to: "A|d1")
        XCTAssertEqual(repository.layouts(for: "A|d1").map(\.id), [layouts[0].id])
        XCTAssertEqual(repository.activeLayout(for: "A|d1")?.id, layouts[0].id)
        repository.moveScreen(from: "A|9", to: "A|d1")
        XCTAssertEqual(repository.layouts(for: "A|d1").count, 1)   // not overwritten
    }

    func testLegacyKeysAreTheNumericOnesOfADisplay() {
        let (repository, _) = oldRepository(["A|757", "A|d1", "B|3"])
        XCTAssertEqual(repository.legacyKeys(ofDisplay: "A"), ["A|757"])
    }

    func testTheDefaultZoneFallsBackToTheFirstOne() {
        var layout = NamedLayout(name: "x", root: .split(id: UUID(), sideBySide: true, ratio: 0.5, first: .leaf(UUID()), second: .leaf(UUID())))
        XCTAssertEqual(layout.fallbackZoneID, layout.root.leafIDs[0])
        layout.defaultZoneID = layout.root.leafIDs[1]
        XCTAssertEqual(layout.fallbackZoneID, layout.root.leafIDs[1])
        layout.defaultZoneID = UUID()   // a zone that is gone
        XCTAssertEqual(layout.fallbackZoneID, layout.root.leafIDs[0])
    }

    func testOldLayoutFilesWithoutADefaultZoneStillLoad() throws {
        let layout = NamedLayout(name: "x", root: .leaf(UUID()))
        let data = try JSONEncoder().encode(layout)
        var object = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        object["defaultZoneID"] = nil
        let stripped = try JSONSerialization.data(withJSONObject: object)
        XCTAssertNil(try JSONDecoder().decode(NamedLayout.self, from: stripped).defaultZoneID)
    }
}
