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

    func testATitleChangeIsWrittenWithTheNextRealChange() {
        let store = MemoryStore()
        let memory = StackMemory(store: store)
        let slot = memory.remember(zoneID: UUID(), bundleID: "com.example.editor", title: "Notes")
        memory.bind(slot: slot, toWindow: 42, title: "Notes")

        memory.updateTitle(ofWindow: 42, to: "Inbox")
        XCTAssertEqual(memory.records[0].title, "Inbox")
        XCTAssertEqual(StackMemory(store: store).records[0].title, "Notes", "a title alone is not written")

        memory.unbind(window: 42)
        XCTAssertEqual(StackMemory(store: store).records[0].title, "Inbox")
    }

    func testASlotMovedToThePlaceOfAnotherKeepsItsWindowAndTheOthersMoveOnePlace() {
        let memory = StackMemory(store: MemoryStore())
        let zone = UUID()
        let slots = ["a", "b", "c"].map { memory.remember(zoneID: zone, bundleID: $0, title: "") }
        memory.bind(slot: slots[0], toWindow: 1, title: "")

        memory.moveSlot(0, toPlaceOf: 2)
        XCTAssertEqual(memory.records.map(\.bundleID), ["b", "c", "a"], "moved down: after it")
        XCTAssertEqual(memory.records[2].windowID, 1)
        memory.moveSlot(2, toPlaceOf: 0)
        XCTAssertEqual(memory.records.map(\.bundleID), ["a", "b", "c"], "moved up: before it")
        memory.moveSlot(1, toPlaceOf: 1)
        memory.moveSlot(1, toPlaceOf: 9)
        XCTAssertEqual(memory.records.map(\.bundleID), ["a", "b", "c"], "nowhere to go: nothing changes")
    }

    func testASlotCanBePlacedBesideAnotherOneFromEitherSide() {
        for (i, j, after, expected) in [(3, 1, false, ["a", "d", "b", "c"]), (3, 1, true, ["a", "b", "d", "c"]),
                                        (0, 2, false, ["b", "a", "c", "d"]), (0, 2, true, ["b", "c", "a", "d"]),
                                        (3, 3, true, ["a", "b", "c", "d"])] {
            let memory = StackMemory(store: MemoryStore())
            let zone = UUID()
            for b in ["a", "b", "c", "d"] { _ = memory.remember(zoneID: zone, bundleID: b, title: "") }
            memory.moveSlot(i, toPlaceOf: StackMemory.place(of: i, beside: j, after: after))
            XCTAssertEqual(memory.records.map(\.bundleID), expected, "slot \(i) \(after ? "after" : "before") slot \(j)")
        }
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

    func testALayoutSeesItsOwnZonesInMemoryOrder() {
        let memory = StackMemory(store: MemoryStore())
        let a = UUID(), b = UUID(), other = UUID()
        memory.remember(zoneID: a, bundleID: "one", title: "")
        memory.remember(zoneID: other, bundleID: "two", title: "")
        memory.remember(zoneID: b, bundleID: "three", title: "")
        XCTAssertEqual(memory.slots(inZones: [a, b]).map(\.bundleID), ["one", "three"])
        XCTAssertEqual(memory.slots(inZones: [other]).map(\.bundleID), ["two"])
    }

    func testAssigningMovesASlotAndReleasesItsWindow() {
        let memory = StackMemory(store: MemoryStore())
        let a = UUID(), b = UUID()
        let slot = memory.remember(zoneID: a, bundleID: "one", title: "")
        memory.bind(slot: slot, toWindow: 7, title: "x")
        XCTAssertEqual(memory.assign(slot: slot, toZone: b, among: [a, b]), 7)
        XCTAssertEqual(memory.records[slot].zoneID, b)
        XCTAssertNil(memory.records[slot].windowID)
    }

    func testAssigningInAnotherLayoutChangesOnlyThatLayoutsZone() {
        let memory = StackMemory(store: MemoryStore())
        let x = UUID(), x2 = UUID(), y = UUID()
        let slot = memory.remember(zoneID: x, bundleID: "one", title: "")
        memory.remap([x: y])   // the slot now lives in layout B's zone y and remembers x
        memory.assign(slot: slot, toZone: x2, among: [x, x2])
        XCTAssertEqual(memory.records[slot].zoneID, y)
        XCTAssertEqual(memory.records[slot].otherZones, [x2])
    }

    func testANewWindowOfAnAppStandsNextToItsOthers() {
        let memory = StackMemory(store: MemoryStore())
        let a = UUID(), b = UUID()
        memory.remember(zoneID: a, bundleID: "one", title: "")
        memory.remember(zoneID: a, bundleID: "two", title: "")
        memory.remember(zoneID: b, bundleID: "one", title: "other zone")
        let index = memory.remember(zoneID: a, bundleID: "one", title: "second")
        XCTAssertEqual(index, 1)
        XCTAssertEqual(memory.records.map(\.title), ["", "second", "", "other zone"])
    }

    func testAnAppIsOneEntryWhateverItsWindows() {
        let memory = StackMemory(store: MemoryStore())
        let a = UUID()
        memory.remember(zoneID: a, bundleID: "one", title: "1")
        memory.remember(zoneID: a, bundleID: "two", title: "")
        memory.remember(zoneID: a, bundleID: "one", title: "2")
        let apps = memory.apps(inZones: [a])
        XCTAssertEqual(apps.map(\.bundleID), ["one", "two"])
        XCTAssertEqual(apps[0].slots.map(\.title), ["1", "2"])
    }

    func testMovingAnAppMovesAllItsWindowsPastTheNextApp() {
        let memory = StackMemory(store: MemoryStore())
        let a = UUID()
        memory.remember(zoneID: a, bundleID: "one", title: "1")
        memory.remember(zoneID: a, bundleID: "one", title: "2")
        memory.remember(zoneID: a, bundleID: "two", title: "")
        memory.moveApp("one", inZone: a, by: 1, among: [a])
        XCTAssertEqual(memory.records.map(\.bundleID), ["two", "one", "one"])
        XCTAssertTrue(memory.moveApp("one", inZone: a, by: 1, among: [a]).isEmpty)
    }

    func testMovingAnAppSeveralPlacesShiftsTheOnesInBetween() {
        let memory = StackMemory(store: MemoryStore())
        let a = UUID()
        for app in ["one", "two", "three"] { memory.remember(zoneID: a, bundleID: app, title: "") }
        memory.moveApp("one", inZone: a, by: 2, among: [a])
        XCTAssertEqual(memory.records.map(\.bundleID), ["two", "three", "one"])
    }

    func testMovingAWindowStaysAmongTheWindowsOfItsApp() {
        let memory = StackMemory(store: MemoryStore())
        let a = UUID()
        memory.remember(zoneID: a, bundleID: "one", title: "1")
        memory.remember(zoneID: a, bundleID: "one", title: "2")
        memory.remember(zoneID: a, bundleID: "two", title: "")
        memory.moveWindow(1, by: -1, among: [a])
        XCTAssertEqual(memory.records.map(\.title), ["2", "1", ""])
        XCTAssertTrue(memory.moveWindow(1, by: 1, among: [a]).isEmpty)   // the last window of its app
    }

    func testMovingAWindowSeveralPlacesShiftsTheOnesInBetween() {
        let memory = StackMemory(store: MemoryStore())
        let a = UUID()
        for title in ["1", "2", "3"] { memory.remember(zoneID: a, bundleID: "one", title: title) }
        memory.moveWindow(0, by: 2, among: [a])
        XCTAssertEqual(memory.records.map(\.title), ["2", "3", "1"])
    }

    func testASlotThatOnlyRemembersAZoneIsNotInIt() {
        let home = UUID(), beyond = UUID()
        let memory = StackMemory(store: MemoryStore())
        _ = memory.remember(zoneID: beyond, bundleID: "com.example.mail", title: "Inbox")
        memory.remap([beyond: home])                      // the zones beyond the edges are switched off: the slot goes to the default zone
        XCTAssertEqual(memory.slots(inZone: home).map(\.bundleID), ["com.example.mail"])
        memory.remap([home: home], preferred: [beyond])   // and on again: it goes back, remembering the default zone
        XCTAssertEqual(memory.slots(inZones: [home]).map(\.bundleID), ["com.example.mail"], "for a layout the slot still counts")
        XCTAssertEqual(memory.slots(inZone: home).map(\.bundleID), [], "for the zone itself it is elsewhere")
        XCTAssertEqual(memory.slots(inZone: beyond).map(\.bundleID), ["com.example.mail"])
    }

    func testRemovingAnAppForgetsAllItsWindowsInThatZoneOnly() {
        let memory = StackMemory(store: MemoryStore())
        let a = UUID(), b = UUID()
        let slot = memory.remember(zoneID: a, bundleID: "one", title: "1")
        memory.bind(slot: slot, toWindow: 5, title: "1")
        memory.remember(zoneID: a, bundleID: "one", title: "2")
        memory.remember(zoneID: b, bundleID: "one", title: "kept")
        XCTAssertEqual(memory.removeApp("one", inZone: a, among: [a, b]), [5])
        XCTAssertEqual(memory.records.map(\.title), ["kept"])
    }

    func testClosedWindowsOfOneAppAndZoneLeaveOneWaitingSlot() {
        let memory = StackMemory(store: MemoryStore())
        let zone = UUID()
        let a = memory.remember(zoneID: zone, bundleID: "app", title: "one")
        let b = memory.remember(zoneID: zone, bundleID: "app", title: "two")
        memory.bind(slot: a, toWindow: 1, title: "one")
        memory.bind(slot: b, toWindow: 2, title: "two")
        memory.unbind(window: 1)
        memory.unbind(window: 2)
        XCTAssertEqual(memory.records.map(\.title), ["two"])
    }

    func testDisplacedSlotsKeepTheirHomeAndGoBackToItWhenTheDisplayReturns() {
        let memory = StackMemory(store: MemoryStore())
        let away = UUID(), here = UUID()
        let a = memory.remember(zoneID: away, bundleID: "app", title: "")
        let b = memory.remember(zoneID: away, bundleID: "app", title: "")
        memory.bind(slot: a, toWindow: 1, title: "")

        XCTAssertEqual(memory.displace(zones: [away]), [1], "only the slot with a live window")
        XCTAssertEqual(memory.records[a].home, away)
        XCTAssertNil(memory.records[b].home)

        memory.setHome(slot: memory.remember(zoneID: here, bundleID: "app", title: ""), to: away)

        XCTAssertEqual(memory.returnHome(to: [away]), [1], "the live window is released to be attached again")
        XCTAssertEqual(memory.records[a].windowID, nil)
        XCTAssertEqual(memory.records.map(\.home), [nil, nil, nil])
        XCTAssertEqual(memory.records.map(\.zoneID), [away, away, away])
    }
}
