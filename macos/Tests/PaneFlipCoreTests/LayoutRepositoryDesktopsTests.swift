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
}
