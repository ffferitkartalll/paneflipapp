import XCTest
@testable import PaneFlipCore

final class NamedLayoutFileTests: XCTestCase {
    func testAnImportedLayoutHasTheShapeAndNamesOfTheFileAndZonesOfItsOwn() throws {
        var layout = NamedLayout(name: "Work", root: LayoutPreset.all[1].root)
        layout.zoneNames[layout.root.leafIDs[0]] = "Mail"
        layout.startApps = ["com.example.app"]
        layout.gap = 8

        let data = try layout.exported()
        let first = try NamedLayout.imported(from: data)
        let second = try NamedLayout.imported(from: data)

        XCTAssertEqual(first.name, "Work")
        XCTAssertEqual(first.gap, 8)
        XCTAssertEqual(first.startApps, ["com.example.app"])
        XCTAssertEqual(first.root.leafIDs.count, 3)
        XCTAssertEqual(first.zoneNames.values.sorted(), ["Mail"])
        XCTAssertNotEqual(first.id, layout.id)
        XCTAssertTrue(Set(first.root.leafIDs).isDisjoint(with: second.root.leafIDs), "two imports share no zone")
        XCTAssertTrue(Set(first.root.leafIDs).isDisjoint(with: layout.root.leafIDs))
    }

    func testAFileThatIsNotALayoutIsRefused() {
        XCTAssertThrowsError(try NamedLayout.imported(from: Data("{}".utf8)))
    }

    func testTheRepositoryKeepsAnImportedLayoutOnItsDisplay() throws {
        let repository = LayoutRepository(store: MemoryStore())
        let layout = try NamedLayout.imported(from: NamedLayout(name: "A", root: .leaf(UUID())).exported())
        repository.importLayout(layout, key: "D|d1")
        XCTAssertEqual(repository.layouts(for: "D|d1").map(\.id), [layout.id])
    }
}
