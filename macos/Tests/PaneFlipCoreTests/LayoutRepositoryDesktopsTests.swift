import XCTest
@testable import PaneFlipCore

final class LayoutRepositoryDesktopsTests: XCTestCase {
    func testADisplaysLayoutsAreSharedAndEachDesktopHasItsOwn() {
        let repository = LayoutRepository(store: MemoryStore())
        let first = repository.addLayout(for: "A|d1")
        let second = repository.addLayout(for: "A|d1")

        XCTAssertEqual(repository.layouts(for: "A|d2").map(\.id), [first.id, second.id])
        XCTAssertNil(repository.activeLayout(for: "A|d2"), "a desktop has no layout until one is chosen")

        repository.activate(layout: second.id, key: "A|d2")

        XCTAssertEqual(repository.activeLayout(for: "A|d1")?.id, first.id)
        XCTAssertEqual(repository.activeLayout(for: "A|d2")?.id, second.id)
    }

    func testALayoutServesOneDesktopAtATime() {
        let repository = LayoutRepository(store: MemoryStore())
        let first = repository.addLayout(for: "A|d1")

        XCTAssertTrue(repository.isTaken(layout: first.id, key: "A|d2"))
        XCTAssertFalse(repository.isTaken(layout: first.id, key: "A|d1"))
        repository.activate(layout: first.id, key: "A|d2")
        XCTAssertNil(repository.activeLayout(for: "A|d2"))

        repository.deactivate(key: "A|d1")
        repository.activate(layout: first.id, key: "A|d2")
        XCTAssertEqual(repository.activeLayout(for: "A|d2")?.id, first.id)
    }

    func testRemovingALayoutLeavesItsDesktopsWithoutOne() {
        let repository = LayoutRepository(store: MemoryStore())
        let first = repository.addLayout(for: "A|d1")
        repository.addLayout(for: "A|d1")

        repository.removeLayout(id: first.id, key: "A|d1")

        XCTAssertNil(repository.activeLayout(for: "A|d1"))
        XCTAssertEqual(repository.layouts(for: "A|d1").count, 1)
    }

    func testAnOldDocumentWithALayoutListPerDesktopIsGatheredPerDisplay() {
        let store = MemoryStore()
        let one = NamedLayout(name: "one", root: .leaf(UUID())), two = NamedLayout(name: "two", root: .leaf(UUID()))
        let three = NamedLayout(name: "three", root: .leaf(UUID()))
        store.save(["A|d1": ScreenLayouts(layouts: [one, two], activeID: two.id),
                    "A|d2": ScreenLayouts(layouts: [three], activeID: three.id)], named: "layouts-v2")

        let repository = LayoutRepository(store: store)

        XCTAssertEqual(Set(repository.layouts(for: "A|d1").map(\.id)), [one.id, two.id, three.id])
        XCTAssertEqual(repository.activeLayout(for: "A|d1")?.id, two.id)
        XCTAssertEqual(repository.activeLayout(for: "A|d2")?.id, three.id)
    }

    func testARemovedDesktopStopsHoldingItsLayout() {
        let repository = LayoutRepository(store: MemoryStore())
        let first = repository.addLayout(for: "A|d1")
        let second = repository.addLayout(for: "A|d1")
        repository.activate(layout: second.id, key: "A|d2")

        repository.forgetDesktops(ofDisplay: "A", after: 1)

        XCTAssertNil(repository.activeLayout(for: "A|d2"))
        XCTAssertEqual(repository.activeLayout(for: "A|d1")?.id, first.id)
        XCTAssertFalse(repository.isTaken(layout: second.id, key: "A|d1"))
    }

    func testACopyHasZonesOfItsOwnAndNoDesktop() {
        let repository = LayoutRepository(store: MemoryStore())
        let original = repository.addLayout(for: "A|d1")
        var strip = original.strip
        strip.root = strip.root.splitting(strip.root.leafIDs[0], sideBySide: true, ratio: 0.4)
        strip.trailing = Overflow(width: 0.25, root: .leaf(UUID()))
        repository.setStrip(strip, ofLayout: original.id, key: "A|d1")
        repository.setDefaultZone(strip.root.leafIDs[1], ofLayout: original.id, key: "A|d1")
        let source = repository.layout(id: original.id, key: "A|d1")!

        let copy = repository.duplicateLayout(id: original.id, key: "A|d1", named: "Copy")!

        XCTAssertEqual(repository.layouts(for: "A|d1").map(\.id), [original.id, copy.id])
        XCTAssertTrue(Set(copy.strip.zoneIDs).isDisjoint(with: source.strip.zoneIDs))
        XCTAssertEqual(copy.strip.zoneIDs.count, source.strip.zoneIDs.count)
        XCTAssertEqual(copy.defaultZoneID, copy.root.leafIDs[1])
        XCTAssertEqual(copy.trailing?.width, 0.25)
        XCTAssertEqual(repository.activeLayout(for: "A|d1")?.id, original.id)
        XCTAssertFalse(repository.isTaken(layout: copy.id, key: "A|d1"))
    }

    func testEveryPresetMakesZonesNoOtherLayoutShares() {
        XCTAssertEqual(LayoutPreset.all.count, 20)
        XCTAssertEqual(Set(LayoutPreset.all.map(\.id)).count, LayoutPreset.all.count)

        let repository = LayoutRepository(store: MemoryStore())
        let layouts = LayoutPreset.all.map { repository.addLayout(for: "A|d1", preset: $0) }

        XCTAssertEqual(layouts.map { $0.root.leafIDs.count },
                       [2, 3, 4, 2, 3, 4, 6, 6, 9, 2, 2, 2, 3, 3, 3, 3, 4, 4, 3, 3])
        XCTAssertEqual(Set(layouts.flatMap(\.root.leafIDs)).count, layouts.map { $0.root.leafIDs.count }.reduce(0, +))
    }

    func testALayoutKeepsItsOwnGapUntilItIsResetAndCopiesIt() {
        let repository = LayoutRepository(store: MemoryStore())
        let layout = repository.addLayout(for: "A|d1")
        XCTAssertNil(layout.gap, "the gap of the settings applies")

        repository.setGap(16, ofLayout: layout.id, key: "A|d1")
        let copy = repository.duplicateLayout(id: layout.id, key: "A|d1", named: "Copy")!

        XCTAssertEqual(repository.activeLayout(for: "A|d1")?.gap, 16)
        XCTAssertEqual(copy.gap, 16)

        repository.setGap(nil, ofLayout: layout.id, key: "A|d1")
        XCTAssertNil(repository.activeLayout(for: "A|d1")?.gap)
    }
}
