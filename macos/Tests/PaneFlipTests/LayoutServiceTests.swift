import XCTest
import PaneFlipCore

final class LayoutServiceTests: XCTestCase {
    func testRemovingALayoutForgetsOnlyTheAppsOfItsZones() {
        let repository = LayoutRepository(store: MemoryDocumentStore())
        let memory = StackMemory(store: MemoryDocumentStore())
        let coordinator = StackCoordinator(windows: FakeWindowSystem(), memory: memory,
                                           settings: AppSettings(storage: StubSettingsStorage()), apps: FakeApps())
        let service = LayoutService(repository: repository, memory: memory, coordinator: coordinator, screens: FakeScreens())
        let first = repository.addLayout(for: "screen")
        let second = repository.addLayout(for: "screen")
        memory.remember(zoneID: first.root.leafIDs[0], bundleID: "kept", title: "")
        memory.remember(zoneID: second.root.leafIDs[0], bundleID: "gone", title: "")

        service.removeLayout(key: "screen", id: second.id)

        XCTAssertEqual(memory.records.map(\.bundleID), ["kept"])
        XCTAssertEqual(repository.activeLayout(for: "screen")?.id, first.id)
    }

    func testRemovingAScreenBeyondTheEdgeMovesItsAppsToTheDefaultZone() {
        let repository = LayoutRepository(store: MemoryDocumentStore())
        let memory = StackMemory(store: MemoryDocumentStore())
        let coordinator = StackCoordinator(windows: FakeWindowSystem(), memory: memory,
                                           settings: AppSettings(storage: StubSettingsStorage()), apps: FakeApps())
        let service = LayoutService(repository: repository, memory: memory, coordinator: coordinator, screens: FakeScreens())
        let layout = repository.addLayout(for: "screen")
        service.activate(key: "screen", id: layout.id)
        var strip = layout.strip
        let beyond = UUID()
        strip.trailing = [Overflow(width: 0.25, root: .leaf(beyond))]
        repository.setStrip(strip, ofLayout: layout.id, key: "screen")
        memory.remember(zoneID: beyond, bundleID: "app", title: "")

        service.updateLayout(key: "screen", id: layout.id, strip: layout.strip)

        XCTAssertEqual(memory.records.map(\.zoneID), [layout.root.leafIDs[0]])
    }

    func testSwitchingLayoutsSendsEveryAppToTheNewDefaultZoneAndBackToWhereItWas() {
        let repository = LayoutRepository(store: MemoryDocumentStore())
        let memory = StackMemory(store: MemoryDocumentStore())
        let coordinator = StackCoordinator(windows: FakeWindowSystem(), memory: memory,
                                           settings: AppSettings(storage: StubSettingsStorage()), apps: FakeApps())
        let service = LayoutService(repository: repository, memory: memory, coordinator: coordinator, screens: FakeScreens())
        let first = repository.addLayout(for: "screen")
        var strip = first.strip
        let beyond = UUID(), second = UUID()
        strip.trailing = [Overflow(width: 0.25, root: .leaf(beyond))]
        repository.setStrip(strip, ofLayout: first.id, key: "screen")
        let other = repository.addLayout(for: "screen")
        var otherStrip = other.strip
        otherStrip.root = .split(id: UUID(), sideBySide: true, ratio: 0.5, first: .leaf(other.root.leafIDs[0]), second: .leaf(second))
        repository.setStrip(otherStrip, ofLayout: other.id, key: "screen")
        repository.setDefaultZone(second, ofLayout: other.id, key: "screen")
        memory.remember(zoneID: first.root.leafIDs[0], bundleID: "inside", title: "")
        memory.remember(zoneID: beyond, bundleID: "outside", title: "")

        service.activate(key: "screen", id: other.id)

        XCTAssertEqual(memory.records.map(\.zoneID), [second, second])

        service.activate(key: "screen", id: first.id)

        XCTAssertEqual(memory.records.map(\.zoneID), [first.root.leafIDs[0], beyond])
    }
}
