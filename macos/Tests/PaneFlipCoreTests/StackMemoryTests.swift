import XCTest
@testable import PaneFlipCore

final class StackMemoryTests: XCTestCase {
    func testRecordsSurviveReload() {
        let store = MemoryStore()
        let zone = UUID()
        let memory = StackMemory(store: store)
        let slot = memory.remember(zoneID: zone, bundleID: "com.example.editor", title: "Notes")
        memory.bind(slot: slot, toWindow: 42, title: "Inbox")

        let reloaded = StackMemory(store: store)
        XCTAssertEqual(reloaded.records.count, 1)
        XCTAssertNil(reloaded.records[0].windowID, "window numbers are not persisted")
        XCTAssertEqual(reloaded.records[0].zoneID, zone)
    }

    func testUnbindKeepsTheSlotForgetRemovesIt() {
        let memory = StackMemory(store: MemoryStore())
        let zone = UUID()
        let i = memory.remember(zoneID: zone, bundleID: "a", title: "")
        memory.bind(slot: i, toWindow: 1, title: "")
        memory.unbind(window: 1)
        XCTAssertEqual(memory.records.count, 1)
        XCTAssertNil(memory.records[0].windowID)

        memory.bind(slot: 0, toWindow: 2, title: "")
        memory.forget(window: 2)
        XCTAssertTrue(memory.records.isEmpty)
    }

    func testApplyOrderRearrangesLiveSlotsOnly() {
        let memory = StackMemory(store: MemoryStore())
        let zone = UUID()
        let a = memory.remember(zoneID: zone, bundleID: "a", title: "")
        let b = memory.remember(zoneID: zone, bundleID: "b", title: "")
        memory.bind(slot: a, toWindow: 1, title: "")
        memory.bind(slot: b, toWindow: 2, title: "")
        memory.applyOrder(zoneID: zone, windowOrder: [2, 1])
        XCTAssertEqual(memory.records.map(\.bundleID), ["b", "a"])
    }

    func testRemapReleasesBoundWindows() {
        let memory = StackMemory(store: MemoryStore())
        let old = UUID(), new = UUID()
        let i = memory.remember(zoneID: old, bundleID: "a", title: "")
        memory.bind(slot: i, toWindow: 7, title: "")
        let released = memory.remap([old: new])
        XCTAssertEqual(released, [7])
        XCTAssertEqual(memory.records[0].zoneID, new)
        XCTAssertNil(memory.records[0].windowID)
    }

    func testPruneDropsSlotsOfDeletedZones() {
        let memory = StackMemory(store: MemoryStore())
        let keep = UUID(), drop = UUID()
        memory.remember(zoneID: keep, bundleID: "a", title: "")
        memory.remember(zoneID: drop, bundleID: "b", title: "")
        memory.prune(keepingZones: [keep])
        XCTAssertEqual(memory.records.map(\.bundleID), ["a"])
    }

    func testUnboundSlotsAreInArrangedOrderAndSkipEmptyBundles() {
        let memory = StackMemory(store: MemoryStore())
        let zone = UUID()
        memory.remember(zoneID: zone, bundleID: "a", title: "")
        memory.remember(zoneID: zone, bundleID: "", title: "")
        memory.remember(zoneID: zone, bundleID: "c", title: "")
        XCTAssertEqual(memory.unboundSlots(in: [zone]), [0, 2])
    }

    func testSlotsGoBackToTheZonesOfALayoutThatBecomesActiveAgain() {
        let memory = StackMemory(store: MemoryStore())
        let a1 = UUID(), a2 = UUID(), b = UUID()
        let first = memory.remember(zoneID: a1, bundleID: "a", title: "")
        let second = memory.remember(zoneID: a2, bundleID: "b", title: "")

        // Layout A (two zones) → layout B (one zone): both slots collapse onto its zone.
        memory.remap([a1: b, a2: b], preferred: [b])
        XCTAssertEqual(memory.records.map(\.zoneID), [b, b])

        // Back to A: each slot returns to the zone it had there.
        memory.remap([b: a1], preferred: [a1, a2])
        XCTAssertEqual(memory.records[first].zoneID, a1)
        XCTAssertEqual(memory.records[second].zoneID, a2)
    }

    func testWithoutAHomeASlotFollowsTheMap() {
        let memory = StackMemory(store: MemoryStore())
        let old = UUID(), new = UUID()
        memory.remember(zoneID: old, bundleID: "a", title: "")
        memory.remap([old: new], preferred: [UUID()])
        XCTAssertEqual(memory.records[0].zoneID, new)
    }

    func testOldFilesWithoutOtherZonesStillLoad() throws {
        let json = #"[{"id":"\#(UUID())","zoneID":"\#(UUID())","bundleID":"a","title":""}]"#
        let records = try JSONDecoder().decode([StackRecord].self, from: Data(json.utf8))
        XCTAssertEqual(records[0].otherZones, [])
    }

    func testPruneForgetsZonesThatAreGone() {
        let memory = StackMemory(store: MemoryStore())
        let kept = UUID(), other = UUID()
        memory.remember(zoneID: kept, bundleID: "a", title: "")
        memory.remap([kept: other], preferred: [])
        memory.remap([other: kept], preferred: [])
        XCTAssertEqual(memory.records[0].otherZones, [other])
        memory.prune(keepingZones: [kept])
        XCTAssertEqual(memory.records[0].otherZones, [])
    }
}
