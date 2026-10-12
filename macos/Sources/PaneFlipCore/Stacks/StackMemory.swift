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

    // MARK: Commands

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
