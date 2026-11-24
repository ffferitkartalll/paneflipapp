import XCTest
@testable import PaneFlipCore

final class NamedLayoutFileTests: XCTestCase {
    func testAnImportedLayoutHasTheShapeAndNamesOfTheFileAndZonesOfItsOwn() throws {
        var layout = NamedLayout(name: "Work", root: LayoutPreset.all[1].root)
        layout.zoneNames[layout.root.leafIDs[0]] = "Mail"
        layout.startApps = ["com.example.app"]

        let data = try layout.exported()
        let first = try NamedLayout.imported(from: data)
        let second = try NamedLayout.imported(from: data)

        XCTAssertEqual(first.name, "Work")
        XCTAssertTrue(first.startApps.isEmpty, "the ticks belong to the windows of a scene, not to the file")
        XCTAssertEqual(first.root.leafIDs.count, 3)
        XCTAssertEqual(first.zoneNames.values.sorted(), ["Mail"])
        XCTAssertNotEqual(first.id, layout.id)
        XCTAssertTrue(Set(first.root.leafIDs).isDisjoint(with: second.root.leafIDs), "two imports share no zone")
        XCTAssertTrue(Set(first.root.leafIDs).isDisjoint(with: layout.root.leafIDs))
    }

    func testAFileThatIsNotALayoutIsRefused() {
        XCTAssertThrowsError(try NamedLayout.imported(from: Data("{}".utf8)))
    }

    func testAFileWithValuesTheEditorCannotMakeIsRefused() throws {
        func file(_ change: (inout NamedLayout) -> Void) throws -> Data {
            var layout = NamedLayout(name: "A", root: .split(id: UUID(), sideBySide: true, ratio: 0.5, first: .leaf(UUID()), second: .leaf(UUID())))
            change(&layout)
            return try layout.exported()
        }
        XCTAssertNoThrow(try NamedLayout.imported(from: file { _ in }))
        for ratio in [0.0, 1.0, 1.5, -0.2] {
            XCTAssertThrowsError(try NamedLayout.imported(from: file { $0.root = .split(id: UUID(), sideBySide: true, ratio: ratio, first: .leaf(UUID()), second: .leaf(UUID())) }), "ratio \(ratio)")
        }
        XCTAssertThrowsError(try NamedLayout.imported(from: file { $0.gap = 5000 }))
        XCTAssertThrowsError(try NamedLayout.imported(from: file { $0.edgeMargin = -4 }))
        XCTAssertThrowsError(try NamedLayout.imported(from: file { $0.minZoneSize = 0 }))
        XCTAssertThrowsError(try NamedLayout.imported(from: file { $0.leading = [Overflow(width: 0)] }))
    }

    func testTheRepositoryKeepsAnImportedLayoutOnItsDisplay() throws {
        let repository = LayoutRepository(store: MemoryStore())
        let layout = try NamedLayout.imported(from: NamedLayout(name: "A", root: .leaf(UUID())).exported())
        repository.importLayout(layout, key: "D|d1")
        XCTAssertEqual(repository.layouts(for: "D|d1").map(\.id), [layout.id])
    }
}
