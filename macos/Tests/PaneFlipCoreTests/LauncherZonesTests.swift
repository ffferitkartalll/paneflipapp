import XCTest
@testable import PaneFlipCore

/// The zones of a layout that show a launcher while they hold no window: kept with the layout, in its copies and files, and only for zones the layout still has.
final class LauncherZonesTests: XCTestCase {
    private let a = UUID(), b = UUID()

    private func layout() -> NamedLayout {
        NamedLayout(name: "L", root: .split(id: UUID(), sideBySide: true, ratio: 0.5, first: .leaf(a), second: .leaf(b)))
    }

    func testTheLauncherZonesAreKeptByTheFileAndGoToTheCopiesZones() throws {
        var layout = layout()
        layout.launcherZones = [b]
        let decoded = try JSONDecoder().decode(NamedLayout.self, from: JSONEncoder().encode(layout))
        XCTAssertEqual(decoded.launcherZones, [b])
        let copy = layout.copy(named: "C")
        XCTAssertEqual(copy.launcherZones.count, 1)
        XCTAssertTrue(copy.launcherZones.isDisjoint(with: [a, b]))
    }

    func testOldFilesHaveNoLauncherZones() throws {
        var json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(layout())) as? [String: Any] ?? [:]
        json["launcherZones"] = nil
        let decoded = try JSONDecoder().decode(NamedLayout.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertTrue(decoded.launcherZones.isEmpty)
    }

    func testAZoneThatIsGoneIsLeftOut() {
        let repository = LayoutRepository(store: MemoryStore())
        let layout = layout()
        repository.importLayout(layout, key: "d|1")
        repository.setLauncherZones([a, UUID()], ofLayout: layout.id, key: "d|1")
        XCTAssertEqual(repository.layout(id: layout.id, key: "d|1")?.launcherZones, [a])
        repository.setStrip(StripLayout(root: .leaf(b)), ofLayout: layout.id, key: "d|1")
        XCTAssertTrue(repository.layout(id: layout.id, key: "d|1")?.launcherZones.isEmpty ?? false)
    }

    func testTheDefaultZoneMayBeOneBeyondAnEdge() {
        let beyond = UUID()
        var layout = layout()
        layout.leading = [Overflow(id: UUID(), width: 1, root: .leaf(beyond))]
        layout.defaultZoneID = beyond
        XCTAssertEqual(layout.fallbackZoneID, beyond)
        layout.leading = []
        XCTAssertEqual(layout.fallbackZoneID, a)
    }
}
