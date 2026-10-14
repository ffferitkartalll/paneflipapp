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
}
