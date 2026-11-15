import XCTest
@testable import PaneFlipCore

final class LayoutRepositoryDisplaysTests: XCTestCase {
    private func repository() -> LayoutRepository { LayoutRepository(store: MemoryStore()) }

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

    func testTheStandardLayoutHasOneZoneAndNoSpaceAndNothingBeyondTheEdges() {
        let layout = NamedLayout.standard(name: "Layout 1")
        XCTAssertEqual(layout.root.leafIDs.count, 1)
        XCTAssertEqual(layout.gap, 0)
        XCTAssertEqual(layout.edgeMargin, 0)
        XCTAssertTrue(layout.leading.isEmpty && layout.trailing.isEmpty)
    }

    func testTheLastLayoutOfADisplayIsNeverRemoved() {
        let repository = repository()
        let only = repository.addStandardLayout(for: "A|d1", named: "one")
        repository.removeLayout(id: only.id, key: "A|d1")
        XCTAssertEqual(repository.layouts(for: "A|d1").map(\.id), [only.id])
        XCTAssertEqual(repository.activeLayout(for: "A|d1")?.id, only.id)
        let second = repository.addLayout(for: "A|d1")
        repository.removeLayout(id: only.id, key: "A|d1")
        XCTAssertEqual(repository.layouts(for: "A|d1").map(\.id), [second.id])
    }

    func testAResetLayoutKeepsItsNameAndPlaceAndStartsAgain() {
        let repository = repository()
        let first = repository.addLayout(for: "A|d1", named: "mine", preset: .custom(rows: 2, columns: 2))
        repository.setSpacing(gap: 12, edgeMargin: 8, minZoneSize: 100, ofLayout: first.id, key: "A|d1")
        repository.setStartApp("app", chosen: true, ofLayout: first.id, key: "A|d1")
        let second = repository.addLayout(for: "A|d1", named: "other")

        let fresh = repository.resetLayout(id: first.id, key: "A|d1")

        XCTAssertEqual(repository.layouts(for: "A|d1").map(\.id), [first.id, second.id])
        XCTAssertEqual(fresh?.name, "mine")
        XCTAssertEqual(fresh?.root.leafIDs.count, 1)
        XCTAssertEqual(fresh?.gap, 0)
        XCTAssertEqual(fresh?.edgeMargin, 0)
        XCTAssertTrue(fresh?.startApps.isEmpty ?? false)
        XCTAssertEqual(repository.activeLayout(for: "A|d1")?.id, first.id, "still the one the desktop uses")
    }
}
