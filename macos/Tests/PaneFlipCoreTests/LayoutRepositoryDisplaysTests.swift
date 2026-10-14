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

    func testLayoutsMoveToANewKeyOnlyWhenItIsEmpty() {
        let repository = repository()
        let layout = repository.addLayout(for: "A|757")
        repository.moveScreen(from: "A|757", to: "A|d1")
        XCTAssertEqual(repository.layouts(for: "A|d1").map(\.id), [layout.id])
        XCTAssertTrue(repository.layouts(for: "A|757").isEmpty)
        repository.addLayout(for: "A|9")
        repository.moveScreen(from: "A|9", to: "A|d1")
        XCTAssertEqual(repository.layouts(for: "A|d1").count, 1)   // not overwritten
    }

    func testLegacyKeysAreTheNumericOnesOfADisplay() {
        let repository = repository()
        repository.addLayout(for: "A|757")
        repository.addLayout(for: "A|d1")
        repository.addLayout(for: "B|3")
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
