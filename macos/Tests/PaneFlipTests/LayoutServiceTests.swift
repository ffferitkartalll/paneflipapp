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

        XCTAssertEqual(memory.slots(inZones: repository.layout(id: other.id, key: "screen")!.strip.zoneIDs).map(\.zoneID), [second, second], "the new layout has its own slots")
        XCTAssertEqual(memory.slots(inZones: repository.layout(id: first.id, key: "screen")!.strip.zoneIDs).map(\.zoneID), [first.root.leafIDs[0], beyond], "and the old one keeps its own")

        service.activate(key: "screen", id: first.id)

        XCTAssertEqual(memory.slots(inZones: repository.layout(id: first.id, key: "screen")!.strip.zoneIDs).map(\.zoneID), [first.root.leafIDs[0], beyond])
        XCTAssertEqual(memory.records.count, 4, "nothing is added a second time")
    }

    func testSwitchingLayoutsPutsEachAppInTheZoneThatLiesWhereItsZoneLay() {
        let repository = LayoutRepository(store: MemoryDocumentStore())
        let memory = StackMemory(store: MemoryDocumentStore())
        let coordinator = StackCoordinator(windows: FakeWindowSystem(), memory: memory,
                                           settings: AppSettings(storage: StubSettingsStorage()), apps: FakeApps())
        let service = LayoutService(repository: repository, memory: memory, coordinator: coordinator, screens: FakeScreens())
        let first = repository.addLayout(for: "screen")
        let (left, right) = (UUID(), UUID())
        var strip = first.strip
        strip.root = .split(id: UUID(), sideBySide: true, ratio: 0.5, first: .leaf(left), second: .leaf(right))
        repository.setStrip(strip, ofLayout: first.id, key: "screen")
        repository.setDefaultZone(left, ofLayout: first.id, key: "screen")
        let other = repository.addLayout(for: "screen")
        let (a, b, c) = (UUID(), UUID(), UUID())
        var otherStrip = other.strip
        otherStrip.root = .split(id: UUID(), sideBySide: true, ratio: 0.33, first: .leaf(a), second: .split(id: UUID(), sideBySide: true, ratio: 0.5, first: .leaf(b), second: .leaf(c)))
        repository.setStrip(otherStrip, ofLayout: other.id, key: "screen")
        repository.setDefaultZone(a, ofLayout: other.id, key: "screen")
        memory.remember(zoneID: left, bundleID: "left", title: "")
        memory.remember(zoneID: right, bundleID: "right", title: "")

        service.activate(key: "screen", id: other.id)

        XCTAssertEqual(memory.slots(inZones: repository.layout(id: other.id, key: "screen")!.strip.zoneIDs).map(\.zoneID), [a, c], "the default zone to the default zone, the other to the zone that lies nearest to it")
    }

    func testSwitchingLayoutsPutsTheAppsOfTheZonesBeyondAnEdgeInTheZonesBeyondTheSameEdge() {
        let repository = LayoutRepository(store: MemoryDocumentStore())
        let memory = StackMemory(store: MemoryDocumentStore())
        let coordinator = StackCoordinator(windows: FakeWindowSystem(), memory: memory,
                                           settings: AppSettings(storage: StubSettingsStorage()), apps: FakeApps())
        let service = LayoutService(repository: repository, memory: memory, coordinator: coordinator, screens: FakeScreens())
        let first = repository.addLayout(for: "screen")
        let (left, right) = (UUID(), UUID())
        var strip = first.strip
        strip.leading = [Overflow(width: 0.25, root: .leaf(left))]
        strip.trailing = [Overflow(width: 0.25, root: .leaf(right))]
        repository.setStrip(strip, ofLayout: first.id, key: "screen")
        let other = repository.addLayout(for: "screen")
        let (otherLeft, otherRight) = (UUID(), UUID())
        var otherStrip = other.strip
        otherStrip.leading = [Overflow(width: 0.25, root: .leaf(otherLeft))]
        otherStrip.trailing = [Overflow(width: 0.25, root: .leaf(otherRight))]
        repository.setStrip(otherStrip, ofLayout: other.id, key: "screen")
        memory.remember(zoneID: left, bundleID: "left", title: "")
        memory.remember(zoneID: right, bundleID: "right", title: "")

        service.activate(key: "screen", id: other.id)

        XCTAssertEqual(memory.slots(inZones: repository.layout(id: other.id, key: "screen")!.strip.zoneIDs).map(\.zoneID), [otherLeft, otherRight])
    }

    func testADisplayWithoutALayoutGetsTheStandardOneAndOneWithLayoutsKeepsThem() {
        let repository = LayoutRepository(store: MemoryDocumentStore())
        let memory = StackMemory(store: MemoryDocumentStore())
        let coordinator = StackCoordinator(windows: FakeWindowSystem(), memory: memory,
                                           settings: AppSettings(storage: StubSettingsStorage()), apps: FakeApps())
        let service = LayoutService(repository: repository, memory: memory, coordinator: coordinator, screens: FakeScreens())
        let area = CGRect(x: 0, y: 0, width: 1000, height: 600)
        func info(_ key: String) -> ScreenInfo { ScreenInfo(key: key, name: key, size: area.size, cocoaFrame: area, cocoaVisibleFrame: area, axVisible: area) }
        let kept = repository.addLayout(for: "old|d1")

        service.ensureLayouts(on: [info("old|d1"), info("new|d1")])
        service.ensureLayouts(on: [info("old|d1"), info("new|d1")])   // again: nothing more is added

        XCTAssertEqual(repository.layouts(for: "old|d1").map(\.id), [kept.id])
        let added = repository.layouts(for: "new|d1")
        XCTAssertEqual(added.count, 1)
        XCTAssertEqual(added.first?.root.leafIDs.count, 1)
        XCTAssertEqual(added.first?.gap, 0)
        XCTAssertEqual(added.first?.name, "", "the default layout has no stored name: its title follows the app's language")
        XCTAssertEqual(added.first?.title(in: added), String(localized: "Default"))
        XCTAssertEqual(repository.activeLayout(for: "new|d1")?.id, added.first?.id)
    }

    func testResettingALayoutBringsItsAppsToItsOneZone() {
        let repository = LayoutRepository(store: MemoryDocumentStore())
        let memory = StackMemory(store: MemoryDocumentStore())
        let coordinator = StackCoordinator(windows: FakeWindowSystem(), memory: memory,
                                           settings: AppSettings(storage: StubSettingsStorage()), apps: FakeApps())
        let screens = FakeScreens()
        let area = CGRect(x: 0, y: 0, width: 1000, height: 600)
        screens.infos = [ScreenInfo(key: "screen", name: "screen", size: area.size, cocoaFrame: area, cocoaVisibleFrame: area, axVisible: area)]
        let service = LayoutService(repository: repository, memory: memory, coordinator: coordinator, screens: screens)
        let layout = repository.addLayout(for: "screen", preset: .custom(rows: 1, columns: 2))
        memory.remember(zoneID: layout.root.leafIDs[1], bundleID: "app", title: "")

        service.resetLayout(key: "screen", id: layout.id)

        let fresh = repository.layout(id: layout.id, key: "screen")
        XCTAssertEqual(fresh?.root.leafIDs.count, 1)
        XCTAssertEqual(memory.records.map(\.zoneID), fresh?.root.leafIDs, "the app went to the zone that is left")
    }

    func testTheDefaultLayoutOfADisplayCannotBeRemovedByTheService() {
        let repository = LayoutRepository(store: MemoryDocumentStore())
        let memory = StackMemory(store: MemoryDocumentStore())
        let coordinator = StackCoordinator(windows: FakeWindowSystem(), memory: memory,
                                           settings: AppSettings(storage: StubSettingsStorage()), apps: FakeApps())
        let service = LayoutService(repository: repository, memory: memory, coordinator: coordinator, screens: FakeScreens())
        let only = repository.addLayout(for: "screen")
        memory.remember(zoneID: only.root.leafIDs[0], bundleID: "app", title: "")

        service.removeLayout(key: "screen", id: only.id)

        XCTAssertEqual(repository.layouts(for: "screen").map(\.id), [only.id])
        XCTAssertEqual(memory.records.count, 1, "its apps are not forgotten")
    }

    func testALayoutWithNoNameIsTitledByItsPlaceAndARenamedOneByItsName() {
        let first = NamedLayout.standard(name: ""), second = NamedLayout.standard(name: ""), third = NamedLayout.standard(name: "mine")
        let all = [first, second, third]
        XCTAssertEqual(first.title(in: all), String(localized: "Default"))
        XCTAssertEqual(second.title(in: all), String(localized: "Layout \(2)"))
        XCTAssertEqual(third.title(in: all), "mine")
        XCTAssertEqual(third.defaultTitle(in: all), String(localized: "Layout \(3)"), "what it goes back to")
    }

    func testWhatIsDoneInTheNewLayoutNeverReachesTheOldOne() {
        let repository = LayoutRepository(store: MemoryDocumentStore())
        let memory = StackMemory(store: MemoryDocumentStore())
        let coordinator = StackCoordinator(windows: FakeWindowSystem(), memory: memory,
                                           settings: AppSettings(storage: StubSettingsStorage()), apps: FakeApps())
        let service = LayoutService(repository: repository, memory: memory, coordinator: coordinator, screens: FakeScreens())
        let first = repository.addLayout(for: "screen")
        let other = repository.addLayout(for: "screen")
        let (one, two) = (first.root.leafIDs[0], other.root.leafIDs[0])
        let a = memory.remember(zoneID: one, bundleID: "a", title: "")
        memory.bind(slot: a, toWindow: 1, title: "")
        let b = memory.remember(zoneID: one, bundleID: "b", title: "")
        memory.bind(slot: b, toWindow: 2, title: "")

        XCTAssertEqual(Set(memory.switchLayout(from: [one], to: [two], map: [one: two])), [1, 2], "the windows are given back to be placed again")
        // In the new layout: the order of its apps changes, one is taken out, another opened.
        memory.moveSlot(memory.slots(inZones: [two])[1].index, toPlaceOf: memory.slots(inZones: [two])[0].index)
        memory.removeApp("a", inZone: two, among: [two])
        let c = memory.remember(zoneID: two, bundleID: "c", title: "")
        memory.bind(slot: c, toWindow: 3, title: "")

        memory.switchLayout(from: [two], to: [one], map: [two: one])

        XCTAssertEqual(memory.slots(inZones: [one]).map(\.bundleID), ["a", "b", "c"], "the old layout keeps its apps and their order, and gets the one opened meanwhile")
        XCTAssertTrue(memory.slots(inZones: [one]).allSatisfy { $0.zoneID == one })
    }
}
