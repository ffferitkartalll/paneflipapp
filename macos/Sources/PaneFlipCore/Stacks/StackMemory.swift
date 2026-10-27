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

    /// The slots of one layout, in memory order (the order of the pills).
    public func slots(inZones zones: [UUID]) -> [LayoutSlot] {
        let set = Set(zones)
        return records.indices.compactMap { i in
            guard !records[i].bundleID.isEmpty, let zone = zone(of: records[i], in: set) else { return nil }
            return LayoutSlot(index: i, zoneID: zone, bundleID: records[i].bundleID, title: records[i].title,
                              windowID: records[i].windowID)
        }
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

    /// Puts a slot into another zone of the same layout. Returns the live window that was bound to it (now
    /// unbound), which the caller must release so it is attached to its new zone.
    @discardableResult
    public func assign(slot i: Int, toZone zone: UUID, among zones: Set<UUID>) -> CGWindowID? {
        guard records.indices.contains(i), zones.contains(zone),
              let current = self.zone(of: records[i], in: zones), current != zone else { return nil }
        var copy = records
        var released: CGWindowID?
        if zones.contains(copy[i].zoneID) {
            copy[i].zoneID = zone
            released = copy[i].windowID
            copy[i].windowID = nil
        } else if let k = copy[i].otherZones.firstIndex(where: zones.contains) {
            copy[i].otherZones[k] = zone
        }
        records = copy
        return released
    }

    /// Moves a window of an app `offset` places among the windows of that app in its zone (negative earlier,
    /// positive later); the windows in between each move one place the other way. Returns the live windows whose
    /// slot changed (now unbound), which the caller must release so they are attached again in the new order.
    @discardableResult
    public func moveWindow(_ i: Int, by offset: Int, among zones: Set<UUID>) -> [CGWindowID] {
        guard records.indices.contains(i), let zone = self.zone(of: records[i], in: zones) else { return [] }
        let same = records.indices.filter {
            records[$0].bundleID == records[i].bundleID && self.zone(of: records[$0], in: zones) == zone
        }
        guard let position = same.firstIndex(of: i), same.indices.contains(position + offset), offset != 0 else { return [] }
        var order = same.map { records[$0] }
        order.insert(order.remove(at: position), at: position + offset)
        var copy = records
        var released: [CGWindowID] = []
        for (place, record) in zip(same, order) {
            let old = records[place]
            copy[place] = record
            if old.id != record.id {
                if let window = record.windowID { released.append(window) }
                copy[place].windowID = nil
            }
        }
        records = copy
        return released
    }

    /// Puts the slot `i` in the place of the slot `j`: moved down it comes after it, moved up before it. Its window stays bound to it; the slots in between
    /// each move one place the other way.
    public func moveSlot(_ i: Int, toPlaceOf j: Int) {
        guard i != j, records.indices.contains(i), records.indices.contains(j) else { return }
        var copy = records
        copy.insert(copy.remove(at: i), at: j)
        records = copy
    }

    /// Where slot `i` has to be moved to (`moveSlot(_:toPlaceOf:)`) to end up just before slot `j`, or just after it.
    public static func place(of i: Int, beside j: Int, after: Bool) -> Int {
        after ? (i < j ? j : j + 1) : (i < j ? j - 1 : j)
    }

    /// Moves an app `offset` places among the apps of its zone in that layout, all its windows together; the apps
    /// in between each move one place the other way. Returns the live windows whose slot moved (now
    /// unbound), which the caller must release so they are attached again in the new order.
    @discardableResult
    public func moveApp(_ bundleID: String, inZone zone: UUID, by offset: Int, among zones: Set<UUID>) -> [CGWindowID] {
        let positions = records.indices.filter {
            !records[$0].bundleID.isEmpty && self.zone(of: records[$0], in: zones) == zone
        }
        var order: [String] = []
        for p in positions where !order.contains(records[p].bundleID) { order.append(records[p].bundleID) }
        guard let g = order.firstIndex(of: bundleID), order.indices.contains(g + offset) else { return [] }
        order.insert(order.remove(at: g), at: g + offset)
        let sequence = order.flatMap { b in positions.filter { records[$0].bundleID == b } }
        var copy = records
        var released: [CGWindowID] = []
        for (position, source) in zip(positions, sequence) {
            copy[position] = records[source]
            if position != source {
                if let window = records[source].windowID { released.append(window) }
                copy[position].windowID = nil
            }
        }
        records = copy
        return released
    }

    /// Puts all windows of an app in one zone into another zone of the same layout. Returns the live windows that
    /// were bound (now unbound), which the caller must release.
    @discardableResult
    public func assignApp(_ bundleID: String, inZone zone: UUID, toZone target: UUID, among zones: Set<UUID>) -> [CGWindowID] {
        records.indices
            .filter { records[$0].bundleID == bundleID && self.zone(of: records[$0], in: zones) == zone }
            .compactMap { assign(slot: $0, toZone: target, among: zones) }
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

    /// Drops slots whose zone no longer exists in any layout.
    public func prune(keepingZones alive: Set<UUID>) {
        var kept = records.filter { alive.contains($0.zoneID) }
        for i in kept.indices { kept[i].otherZones.removeAll { !alive.contains($0) } }
        if kept != records { records = kept }
    }
}
