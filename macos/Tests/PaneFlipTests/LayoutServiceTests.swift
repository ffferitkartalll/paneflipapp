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

    func testSwitchingOffTheZonesBeyondTheScreenMovesTheirAppsToTheDefaultZone() {
        let repository = LayoutRepository(store: MemoryDocumentStore())
        let memory = StackMemory(store: MemoryDocumentStore())
        let coordinator = StackCoordinator(windows: FakeWindowSystem(), memory: memory,
                                           settings: AppSettings(storage: StubSettingsStorage()), apps: FakeApps())
        let service = LayoutService(repository: repository, memory: memory, coordinator: coordinator, screens: FakeScreens())
        let layout = repository.addLayout(for: "screen")
        var strip = layout.strip
        let beyond = UUID()
        strip.trailing = Overflow(width: 0.25, root: .leaf(beyond))
        repository.setStrip(strip, ofLayout: layout.id, key: "screen")
        memory.remember(zoneID: beyond, bundleID: "app", title: "")

        service.moveOverflowAppsToDefaultZones()

        XCTAssertEqual(memory.records[0].zoneID, layout.root.leafIDs[0])
    }

    private func screen(_ key: String) -> ScreenInfo {
        let area = CGRect(x: 0, y: 0, width: 1000, height: 600)
        return ScreenInfo(key: key, name: key, size: area.size, cocoaFrame: area, cocoaVisibleFrame: area, axVisible: area)
    }

    func testAppsOfAnUnpluggedDisplayGoToTheDefaultZoneAndComeBack() {
        let repository = LayoutRepository(store: MemoryDocumentStore())
        let memory = StackMemory(store: MemoryDocumentStore())
        let screens = FakeScreens()
        let coordinator = StackCoordinator(windows: FakeWindowSystem(), memory: memory,
                                           settings: AppSettings(storage: StubSettingsStorage()), apps: FakeApps())
        let service = LayoutService(repository: repository, memory: memory, coordinator: coordinator, screens: screens)
        let main = repository.addLayout(for: "main|d1")
        let external = repository.addLayout(for: "external|d1")
        let away = external.root.leafIDs[0]
        memory.remember(zoneID: away, bundleID: "app", title: "")

        screens.infos = [screen("main|d1"), screen("external|d1")]
        service.displaysDidChange()                       // both there
        screens.infos = [screen("main|d1")]
        service.displaysDidChange()                       // the external one is unplugged
        XCTAssertEqual(memory.records[0].zoneID, main.root.leafIDs[0])

        screens.infos = [screen("main|d1"), screen("external|d1")]
        service.displaysDidChange()                       // plugged in again
        XCTAssertEqual(memory.records[0].zoneID, away)
    }
}
