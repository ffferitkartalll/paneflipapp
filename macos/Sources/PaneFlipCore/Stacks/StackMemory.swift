import CoreGraphics
import Foundation

/// The persistent memory of which app belongs in which zone, in the order the user arranged them.
/// Pure bookkeeping: it never touches a window.
public final class StackMemory {
    public private(set) var records: [StackRecord] {
        didSet { if !deferSave { store.save(records, named: Self.documentName) } }
    }
    /// Set while a title changes: titles change constantly, so they are written with the next real change.
    private var deferSave = false
    private let store: DocumentStore
    private static let documentName = "stacks"

    public init(store: DocumentStore) {
        self.store = store
        records = store.load([StackRecord].self, named: Self.documentName) ?? []
    }

    // MARK: Queries

    public func index(ofWindow id: CGWindowID) -> Int? { records.firstIndex { $0.windowID == id } }
    public var boundWindowIDs: Set<CGWindowID> { Set(records.compactMap(\.windowID)) }

    /// Slots waiting for a window, in the order the user arranged them, restricted to `zones`.
    public func unboundSlots(in zones: Set<UUID>) -> [Int] {
        records.indices.filter { records[$0].windowID == nil && zones.contains(records[$0].zoneID) && !records[$0].bundleID.isEmpty }
    }

    /// The zone of `zones` (the zones of one layout) a slot belongs to, if it belongs to that layout at all.
    private func zone(of record: StackRecord, in zones: Set<UUID>) -> UUID? {
        zones.contains(record.zoneID) ? record.zoneID : record.otherZones.first(where: zones.contains)
    }

    /// The slots of one layout, in memory order (the order of the cards).
    public func slots(inZones zones: [UUID]) -> [LayoutSlot] {
        let set = Set(zones)
        return records.indices.compactMap { i in
            guard !records[i].bundleID.isEmpty, let zone = zone(of: records[i], in: set) else { return nil }
            return LayoutSlot(index: i, zoneID: zone, bundleID: records[i].bundleID, title: records[i].title,
                              windowID: records[i].windowID)
        }
    }

    /// The slots that are in one zone now, not those that only remember it as a zone they were in (see `slots(inZones:)`, for which a zone of the layout is
    /// enough).
    public func slots(inZone zone: UUID) -> [LayoutSlot] {
        slots(inZones: [zone]).filter { records[$0.index].zoneID == zone }
    }

    /// The apps of one layout: the slots grouped by app and zone, in the order the apps first appear in memory.
    public func apps(inZones zones: [UUID]) -> [LayoutApp] {
        var result: [LayoutApp] = []
        for slot in slots(inZones: zones) {
            if let i = result.firstIndex(where: { $0.zoneID == slot.zoneID && $0.bundleID == slot.bundleID }) {
                result[i] = LayoutApp(zoneID: slot.zoneID, bundleID: slot.bundleID, slots: result[i].slots + [slot])
            } else {
                result.append(LayoutApp(zoneID: slot.zoneID, bundleID: slot.bundleID, slots: [slot]))
            }
        }
        return result
    }

    // MARK: Commands

    /// Puts the slot `i` in the place of the slot `j`: moved down it comes after it, moved up before it. Its window stays bound to it; the slots in between
    /// each move one place the other way.
    public func moveSlot(_ i: Int, toPlaceOf j: Int) {
        guard i != j, records.indices.contains(i), records.indices.contains(j) else { return }
        var copy = records
        copy.insert(copy.remove(at: i), at: j)
        records = copy
    }

    /// The slots of the same zone that stand right before and right after slot `i`, whether their apps are open or not (the cards of the zone are in this order).
    public func neighbours(ofSlot i: Int) -> (before: UUID?, after: UUID?) {
        guard records.indices.contains(i) else { return (nil, nil) }
        let zone = records[i].zoneID
        let same = { (record: StackRecord) in record.zoneID == zone && !record.bundleID.isEmpty }
        return (records[..<i].last(where: same)?.id, records[(i + 1)...].first(where: same)?.id)
    }

    /// Puts slot `i` back between its former neighbours: just before the one that followed it, else just after the one that preceded it; where it is when both are gone.
    public func moveSlot(_ i: Int, between before: UUID?, and after: UUID?) {
        if let after, let j = records.firstIndex(where: { $0.id == after }) {
            moveSlot(i, toPlaceOf: Self.place(of: i, beside: j, after: false))
        } else if let before, let j = records.firstIndex(where: { $0.id == before }) {
            moveSlot(i, toPlaceOf: Self.place(of: i, beside: j, after: true))
        }
    }

    /// Where slot `i` has to be moved to (`moveSlot(_:toPlaceOf:)`) to end up just before slot `j`, or just after it.
    public static func place(of i: Int, beside j: Int, after: Bool) -> Int {
        after ? (i < j ? j : j + 1) : (i < j ? j - 1 : j)
    }

    /// Forgets an app of one zone with all its windows. Returns the live windows, which the caller must release.
    @discardableResult
    public func removeApp(_ bundleID: String, inZone zone: UUID, among zones: Set<UUID>) -> [CGWindowID] {
        let gone = records.filter { $0.bundleID == bundleID && self.zone(of: $0, in: zones) == zone }
        records.removeAll { record in gone.contains { $0.id == record.id } }
        return gone.compactMap(\.windowID)
    }


    /// Adds a new slot and returns its index: right after the last slot of the same app in that zone when there is
    /// one (an app's windows stay together), else at the end.
    @discardableResult
    public func remember(zoneID: UUID, bundleID: String, title: String) -> Int {
        let record = StackRecord(zoneID: zoneID, bundleID: bundleID, title: title)
        let after = bundleID.isEmpty ? nil : records.lastIndex { $0.zoneID == zoneID && $0.bundleID == bundleID }
        let index = after.map { $0 + 1 } ?? records.count
        records.insert(record, at: index)
        return index
    }

    public func bind(slot i: Int, toWindow id: CGWindowID, title: String) {
        guard records.indices.contains(i) else { return }
        records[i].windowID = id
        records[i].title = title
    }

    /// The window went away; its slot stays so the app returns to the zone when it reappears. One waiting slot
    /// per app and zone is enough: older ones are forgotten, so closed windows do not pile up.
    public func unbind(window id: CGWindowID) {
        guard let i = index(ofWindow: id) else { return }
        var copy = records
        copy[i].windowID = nil
        let waiting = copy[i]
        copy.removeAll { $0.id != waiting.id && $0.windowID == nil && $0.bundleID == waiting.bundleID && $0.zoneID == waiting.zoneID }
        records = copy
    }

    /// The window was deliberately taken out of its zone; forget it.
    public func forget(window id: CGWindowID) {
        records.removeAll { $0.windowID == id }
    }

    public func updateTitle(ofWindow id: CGWindowID, to title: String) {
        guard let i = index(ofWindow: id), records[i].title != title else { return }
        deferSave = true
        records[i].title = title
        deferSave = false
    }

    /// Re-points slots at new zones. A slot that has been in one of the `preferred` zones before (the zones of a
    /// layout that is becoming active again) goes back there instead of to the zone `map` names. Returns the live
    /// windows that were bound to a moved slot (now unbound), which the caller must release so they get
    /// re-attached to their new zone.
    @discardableResult
    public func remap(_ map: [UUID: UUID], preferred: Set<UUID> = []) -> [CGWindowID] {
        guard !map.isEmpty else { return [] }
        var released: [CGWindowID] = []
        var copy = records
        for i in copy.indices {
            guard let mapped = map[copy[i].zoneID] else { continue }
            let old = copy[i].zoneID
            let new = copy[i].otherZones.first(where: preferred.contains) ?? mapped
            guard new != old else { continue }
            copy[i].otherZones.removeAll { $0 == new }
            if !copy[i].otherZones.contains(old) { copy[i].otherZones.append(old) }
            copy[i].zoneID = new
            if let w = copy[i].windowID { released.append(w); copy[i].windowID = nil }
        }
        records = copy
        return released
    }

    /// The zones of unplugged displays: the slots with a live window in them remember the zone as their home (they keep it when put in a zone
    /// of another display). Returns those windows; their slots stay bound to them.
    @discardableResult
    public func displace(zones: Set<UUID>) -> [CGWindowID] {
        var moved: [CGWindowID] = []
        var copy = records
        for i in copy.indices where zones.contains(copy[i].zoneID) {
            guard let window = copy[i].windowID else { continue }
            copy[i].home = copy[i].home ?? copy[i].zoneID
            moved.append(window)
        }
        records = copy
        return moved
    }

    /// Slots whose home is one of `zones` (their display is back) go there again. Returns the live windows that were bound to them (now unbound), which the
    /// caller must release so they are attached to their zone again.
    @discardableResult
    public func returnHome(to zones: Set<UUID>) -> [CGWindowID] {
        var released: [CGWindowID] = []
        var copy = records
        for i in copy.indices {
            guard let home = copy[i].home, zones.contains(home) else { continue }
            copy[i].zoneID = home
            copy[i].home = nil
            if let window = copy[i].windowID { released.append(window); copy[i].windowID = nil }
        }
        records = copy
        return released
    }

    /// The home of the slot a window is bound to.
    public func home(ofWindow id: CGWindowID) -> UUID? { index(ofWindow: id).flatMap { records[$0].home } }

    /// Gives a slot a home (a window put in a zone gets a new slot, which takes over the home of the old one).
    public func setHome(slot i: Int, to home: UUID?) {
        guard records.indices.contains(i), records[i].home != home else { return }
        records[i].home = home
    }

    /// Drops slots whose zone no longer exists in any layout.
    public func prune(keepingZones alive: Set<UUID>) {
        var kept = records.filter { alive.contains($0.zoneID) }
        for i in kept.indices {
            kept[i].otherZones.removeAll { !alive.contains($0) }
            if let home = kept[i].home, !alive.contains(home) { kept[i].home = nil }
        }
        if kept != records { records = kept }
    }
}
