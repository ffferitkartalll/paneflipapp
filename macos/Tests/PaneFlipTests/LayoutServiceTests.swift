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
        strip.trailing = [Overflow(width: 0.25, root: .leaf(beyond))]
        repository.setStrip(strip, ofLayout: layout.id, key: "screen")
        memory.remember(zoneID: beyond, bundleID: "app", title: "")

        service.moveOverflowAppsToDefaultZones()

        XCTAssertEqual(memory.records[0].zoneID, layout.root.leafIDs[0])

        service.returnOverflowAppsToTheirZones()

        XCTAssertEqual(memory.records[0].zoneID, beyond)
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

    private func screen(_ key: String) -> ScreenInfo {
        let area = CGRect(x: 0, y: 0, width: 1000, height: 600)
        return ScreenInfo(key: key, name: key, size: area.size, cocoaFrame: area, cocoaVisibleFrame: area, axVisible: area)
    }

    func testWindowsOfAnUnpluggedDisplaySpreadOverTheFirstDisplayAndComeBackToTheirZones() {
        let repository = LayoutRepository(store: MemoryDocumentStore())
        let memory = StackMemory(store: MemoryDocumentStore())
        let screens = FakeScreens()
        let windows = FakeWindowSystem()
        let coordinator = StackCoordinator(windows: windows, memory: memory,
                                           settings: AppSettings(storage: StubSettingsStorage()), apps: FakeApps())
        let service = LayoutService(repository: repository, memory: memory, coordinator: coordinator, screens: screens)
        let main = repository.addLayout(for: "main|d1").root.leafIDs[0]
        let away = repository.addLayout(for: "external|d1").root.leafIDs[0]
        let rect = CGRect(x: 0, y: 0, width: 100, height: 100)
        coordinator.apply(zones: [main: rect, away: rect])
        coordinator.snap(.fake(1), into: away)
        coordinator.snap(.fake(2), into: away)

        screens.infos = [screen("main|d1"), screen("external|d1")]
        service.displaysDidChange()                       // both there
        screens.infos = [screen("main|d1")]
        service.displaysDidChange()                       // the external one is unplugged

        XCTAssertEqual(windows.frames[1], CGRect(x: 0, y: 0, width: 1000, height: 600), "spread over the usable area")
        XCTAssertNil(coordinator.stack(containing: 1), "in no zone")
        XCTAssertEqual(memory.records.map(\.zoneID), [away, away])
        XCTAssertEqual(memory.records.map(\.windowID), [1, 2], "the slots stay bound")
        XCTAssertEqual(coordinator.displacedSlot(of: 1), memory.records[0].id, "a displaced window knows its slot")
        XCTAssertEqual(coordinator.displacedSlot(of: 2), memory.records[1].id)

        coordinator.snap(.fake(1), into: main)           // put in a zone of the first display meanwhile
        XCTAssertEqual(memory.records.filter { $0.windowID == 1 }.map(\.home), [away], "the new slot keeps the home")

        screens.infos = [screen("main|d1"), screen("external|d1")]
        service.displaysDidChange()                       // plugged in again
        XCTAssertEqual(memory.records.map(\.zoneID).filter { $0 == away }.count, 2, "both slots are back in the zone they came from")
        XCTAssertEqual(memory.records.map(\.windowID), [nil, nil], "to be attached there again")
        XCTAssertNil(coordinator.stack(containing: 1))
    }
}
