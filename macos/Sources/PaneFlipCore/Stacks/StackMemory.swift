import CoreGraphics
import Foundation

/// The persistent memory of which app belongs in which zone, in the order the user arranged them.
/// Pure bookkeeping: it never touches a window.
public final class StackMemory {
    public private(set) var records: [StackRecord] {
        didSet { if !deferSave { store.save(records, named: documentName) } }
    }
    /// Set while a title changes: titles change constantly, so they are written with the next real change.
    private var deferSave = false
    private let store: DocumentStore
    /// The memory of the scene in use is its own document: the same layout in two scenes keeps its windows apart.
    private var documentName: String
    private static let legacyName = "stacks"

    /// `scene`: the scene in use (nil: the one memory there was before scenes had their own). The first start with scenes takes over what was remembered before them.
    public init(store: DocumentStore, scene: UUID? = nil) {
        self.store = store
        documentName = scene.map(Self.name(of:)) ?? Self.legacyName
        if scene != nil, store.load([StackRecord].self, named: documentName) == nil, let old = store.load([StackRecord].self, named: Self.legacyName), !old.isEmpty {
            records = old
            store.save([StackRecord](), named: Self.legacyName)   // it belongs to this scene now: no other takes it over
            store.save(old, named: documentName)
        } else {
            records = store.load([StackRecord].self, named: documentName) ?? []
        }
    }

    private static func name(of scene: UUID) -> String { "\(legacyName)-\(scene.uuidString)" }

    /// Makes the memory of another scene the one in use (the zones that no longer exist in any layout are dropped from it, see `alive`). Returns the live windows of the memory
    /// that was in use, which the caller must release: the slots of the other scene wait for windows again.
    @discardableResult
    public func switchScene(to scene: UUID, keepingZones alive: Set<UUID>) -> [CGWindowID] {
        let name = Self.name(of: scene)
        guard name != documentName else { return [] }
        let released = Array(boundWindowIDs)
        documentName = name
        records = store.load([StackRecord].self, named: name) ?? []
        prune(keepingZones: alive)
        return released
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

    /// The apps of one layout that are ticked to be started with it.
    public func startApps(inZones zones: [UUID]) -> Set<String> {
        let set = Set(zones)
        return Set(records.filter { $0.start && !$0.bundleID.isEmpty && zone(of: $0, in: set) != nil }.map(\.bundleID))
    }

    // MARK: Commands

    /// Ticks or unticks an app for one layout: all its slots in the layout's zones.
    public func setStart(_ chosen: Bool, app bundleID: String, inZones zones: [UUID]) {
        let set = Set(zones)
        var copy = records
        for i in copy.indices where copy[i].bundleID == bundleID && zone(of: copy[i], in: set) != nil { copy[i].start = chosen }
        if copy != records { records = copy }
    }

    /// Ticks apps in the slots of one layout's zones: what layouts kept before the tick belonged to the slots.
    public func markStart(_ bundleIDs: Set<String>, inZones zones: [UUID]) {
        bundleIDs.forEach { setStart(true, app: $0, inZones: zones) }
    }

    /// Puts the slot `i` in the place of the slot `j`: moved down it comes after it, moved up before it. Its window stays bound to it; the slots in between
    /// each move one place the other way.
    public func moveSlot(_ i: Int, toPlaceOf j: Int) {
        guard i != j, records.indices.contains(i), records.indices.contains(j) else { return }
        var copy = records
        copy.insert(copy.remove(at: i), at: j)
        records = copy
    }

    /// Puts slot `i` in another zone, as the last of its cards there (a card was carried to it); its window, if it has one, is for the caller to put there.
    public func setZone(ofSlot i: Int, to zone: UUID) {
        guard records.indices.contains(i), records[i].zoneID != zone else { return }
        var copy = records
        var record = copy.remove(at: i)
        record.zoneID = zone
        let last = copy.lastIndex { $0.zoneID == zone && !$0.bundleID.isEmpty }.map { $0 + 1 } ?? copy.count
        copy.insert(record, at: last)
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

    /// Puts a slot into another zone of the same layout. Returns the live window that was bound to it (now
    /// unbound), which the caller must release so it is attached to its new zone.
    @discardableResult
    func assign(slot i: Int, toZone zone: UUID, among zones: Set<UUID>) -> CGWindowID? {
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
            records[$0].bundleID == records[i].bundleID && records[$0].windowID != nil && self.zone(of: records[$0], in: zones) == zone   // the sheet lists the open windows only
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

    /// Forgets everything remembered of the zones of one layout: the slots that are in them go, those that are elsewhere now stop remembering them. Returns the live
    /// windows of the slots that went, which the caller must release.
    @discardableResult
    public func forget(zones: Set<UUID>) -> [CGWindowID] {
        var copy = records
        let gone = copy.filter { zones.contains($0.zoneID) }
        copy.removeAll { zones.contains($0.zoneID) }
        for i in copy.indices { copy[i].otherZones.removeAll(where: zones.contains) }
        if copy != records { records = copy }
        return gone.compactMap(\.windowID)
    }

    /// Forgets an app of one zone with all its windows. A slot of the app that is in a zone of another layout now and only remembers this one stays there and forgets it.
    /// Returns the live windows of the slots that went, which the caller must release.
    @discardableResult
    public func removeApp(_ bundleID: String, inZone zone: UUID, among zones: Set<UUID>) -> [CGWindowID] {
        var copy = records
        let gone = copy.filter { $0.bundleID == bundleID && $0.zoneID == zone }
        copy.removeAll { $0.bundleID == bundleID && $0.zoneID == zone }
        for i in copy.indices where copy[i].bundleID == bundleID { copy[i].otherZones.removeAll { $0 == zone } }
        if copy != records { records = copy }
        return gone.compactMap(\.windowID)
    }


    /// Adds a new slot and returns its index: right after the last slot of the same app in that zone when there is
    /// one (an app's windows stay together), else at the end.
    @discardableResult
    public func remember(zoneID: UUID, bundleID: String, title: String) -> Int {
        var record = StackRecord(zoneID: zoneID, bundleID: bundleID, title: title)
        let after = bundleID.isEmpty ? nil : records.lastIndex { $0.zoneID == zoneID && $0.bundleID == bundleID }
        if let after { record.start = records[after].start }   // a new window of a ticked app is ticked too
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
    ///
    /// `sourceOrder` (the zones in the order of their screens, when a display's windows are put into zones of the others): the slots that moved stand last in their new zone, in the
    /// order of the zones they came from and, from the same zone, in the order they had there.
    @discardableResult
    public func remap(_ map: [UUID: UUID], preferred: Set<UUID> = [], sourceOrder: [UUID] = []) -> [CGWindowID] {
        guard !map.isEmpty else { return [] }
        var released: [CGWindowID] = []
        var copy = records
        var moved: [(slot: StackRecord, from: UUID, at: Int)] = []
        for i in copy.indices {
            guard let mapped = map[copy[i].zoneID] else { continue }
            let old = copy[i].zoneID
            let new = copy[i].otherZones.first(where: preferred.contains) ?? mapped
            guard new != old else { continue }
            moved.append((copy[i], old, i))
            copy[i].otherZones.removeAll { $0 == new }
            if !copy[i].otherZones.contains(old) { copy[i].otherZones.append(old) }
            copy[i].zoneID = new
            if let w = copy[i].windowID { released.append(w); copy[i].windowID = nil }
        }
        if !sourceOrder.isEmpty { copy = Self.ordered(copy, moved: moved.map(\.at), by: moved.map { ($0.at, sourceOrder.firstIndex(of: $0.from) ?? sourceOrder.count) }) }
        records = copy
        return released
    }

    /// The slots at `moved` taken out and put back after the last slot of the zone each has now (at the end when it has none), the ones of one zone in the order of `rank`, then of
    /// their places.
    private static func ordered(_ records: [StackRecord], moved: [Int], by rank: [(at: Int, rank: Int)]) -> [StackRecord] {
        let order = Dictionary(uniqueKeysWithValues: rank.map { ($0.at, $0.rank) })
        let slots = moved.sorted { (order[$0] ?? 0, $0) < (order[$1] ?? 0, $1) }.map { records[$0] }
        var result = records.enumerated().filter { !moved.contains($0.offset) }.map(\.element)
        for slot in slots {
            let after = result.lastIndex { $0.zoneID == slot.zoneID }.map { $0 + 1 } ?? result.count
            result.insert(slot, at: after)
        }
        return result
    }

    /// Another layout of a display takes the place of the one in use (both in the scene in use). Every layout keeps its own slots: what is done to the apps of one never reaches
    /// another. A layout that has no slots yet gets those of the one it replaces, in the zones `map` names (zone of the old layout to zone of the new one). One that has some
    /// gets, for each app, only the slots it lacks for the windows that are open (an app opened since gets its place in the new layout too). Returns the live windows of the
    /// old layout's slots (now unbound), which the caller must release so that they are placed in the zones of the new one.
    @discardableResult
    public func switchLayout(from old: Set<UUID>, to new: Set<UUID>, map: [UUID: UUID]) -> [CGWindowID] {
        var copy = records
        for i in copy.indices { copy[i].otherZones.removeAll(where: new.contains) }   // slots of the new layout that were once only remembered in others: they are its own now
        let leaving = copy.filter { old.contains($0.zoneID) && !$0.bundleID.isEmpty }
        for i in copy.indices where old.contains(copy[i].zoneID) { copy[i].windowID = nil }
        var lacking: [StackRecord]
        if copy.contains(where: { new.contains($0.zoneID) && !$0.bundleID.isEmpty }) {
            var have: [String: Int] = [:]
            for record in copy where new.contains(record.zoneID) { have[record.bundleID, default: 0] += 1 }
            lacking = []
            for record in leaving where record.windowID != nil {
                if have[record.bundleID, default: 0] > 0 { have[record.bundleID]! -= 1 } else { lacking.append(record) }
            }
        } else {
            lacking = leaving
        }
        for var record in lacking {
            guard let zone = map[record.zoneID] else { continue }
            var fresh = StackRecord(zoneID: zone, bundleID: record.bundleID, title: record.title)
            fresh.start = record.start
            record = fresh
            copy.insert(record, at: copy.lastIndex { $0.zoneID == zone }.map { $0 + 1 } ?? copy.count)
        }
        records = copy
        return leaving.compactMap(\.windowID)
    }

    /// Drops slots whose zone no longer exists in any layout.
    public func prune(keepingZones alive: Set<UUID>) {
        var kept = records.filter { alive.contains($0.zoneID) }
        for i in kept.indices {
            kept[i].otherZones.removeAll { !alive.contains($0) }
        }
        if kept != records { records = kept }
    }
}
