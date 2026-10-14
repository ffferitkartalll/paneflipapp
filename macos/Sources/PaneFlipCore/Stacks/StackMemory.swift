import CoreGraphics
import Foundation

/// The persistent memory of which app belongs in which zone, in the order the user arranged them.
/// Pure bookkeeping: it never touches a window.
public final class StackMemory {
    public private(set) var records: [StackRecord] {
        didSet { store.save(records, named: Self.documentName) }
    }
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

    /// Moves a slot `offset` places among the slots of its zone in that layout (-1 earlier, 1 later). Returns the
    /// live windows of the two slots (now unbound), which the caller must release so they are attached again in
    /// the new order.
    @discardableResult
    public func moveSlot(_ i: Int, by offset: Int, among zones: Set<UUID>) -> [CGWindowID] {
        guard records.indices.contains(i), let zone = self.zone(of: records[i], in: zones) else { return [] }
        let same = records.indices.filter { !records[$0].bundleID.isEmpty && self.zone(of: records[$0], in: zones) == zone }
        guard let position = same.firstIndex(of: i), same.indices.contains(position + offset) else { return [] }
        let j = same[position + offset]
        var copy = records
        var released: [CGWindowID] = []
        for k in [i, j] {
            if let window = copy[k].windowID { released.append(window) }
            copy[k].windowID = nil
        }
        copy.swapAt(i, j)
        records = copy
        return released
    }

    /// Forgets a slot. Returns the live window that was bound to it, which the caller must release.
    @discardableResult
    public func removeSlot(_ i: Int) -> CGWindowID? {
        guard records.indices.contains(i) else { return nil }
        return records.remove(at: i).windowID
    }

    /// Adds a new slot at the end and returns its index.
    @discardableResult
    public func remember(zoneID: UUID, bundleID: String, title: String) -> Int {
        records.append(StackRecord(zoneID: zoneID, bundleID: bundleID, title: title))
        return records.count - 1
    }

    public func bind(slot i: Int, toWindow id: CGWindowID, title: String) {
        guard records.indices.contains(i) else { return }
        records[i].windowID = id
        records[i].title = title
    }

    /// The window went away; its slot stays so the app returns to the zone when it reappears.
    public func unbind(window id: CGWindowID) {
        if let i = index(ofWindow: id) { records[i].windowID = nil }
    }

    /// The window was deliberately taken out of its zone; forget it.
    public func forget(window id: CGWindowID) {
        records.removeAll { $0.windowID == id }
    }

    public func updateTitle(ofWindow id: CGWindowID, to title: String) {
        if let i = index(ofWindow: id), records[i].title != title { records[i].title = title }
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

    /// Persists a zone's tab order by rearranging its live slots to match `windowOrder`.
    public func applyOrder(zoneID: UUID, windowOrder: [CGWindowID]) {
        let positions = records.indices.filter { records[$0].zoneID == zoneID && records[$0].windowID != nil }
        let ordered = windowOrder.compactMap { w in records.first { $0.windowID == w } }
        guard positions.count == ordered.count else { return }
        var copy = records
        for (pos, rec) in zip(positions, ordered) { copy[pos] = rec }
        records = copy
    }
}
