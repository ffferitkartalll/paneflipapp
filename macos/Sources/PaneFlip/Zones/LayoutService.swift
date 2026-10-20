import CoreGraphics
import Foundation
import PaneFlipCore

/// Changes layouts and carries the consequences through: the apps of vanished zones move to the zones that cover
/// them, memory is pruned, and the zones are laid out again.
final class LayoutService: LayoutManaging, DisplayChangeHandling {
    private let repository: LayoutRepository
    private let memory: StackMemory
    private let coordinator: StackCoordinator
    private let screens: ScreenProviding
    weak var refresher: ZoneRefreshing?
    /// The displays seen at the last look; empty before the first one.
    private var knownDisplays: Set<String> = []

    init(repository: LayoutRepository, memory: StackMemory, coordinator: StackCoordinator, screens: ScreenProviding) {
        self.repository = repository
        self.memory = memory
        self.coordinator = coordinator
        self.screens = screens
    }

    @discardableResult
    func addLayout(for key: String, preset: LayoutPreset) -> NamedLayout {
        let number = repository.layouts(for: key).count + 1
        let layout = repository.addLayout(for: key, named: String(localized: "Layout \(number)"), preset: preset)
        if repository.activeLayout(for: key)?.id == layout.id { refresher?.refreshZones() }
        return layout
    }

    func duplicate(key: String, id: UUID) {
        repository.duplicateLayout(id: id, key: key, named: String(localized: "Layout \(repository.layouts(for: key).count + 1)"))
    }

    func updateLayout(key: String, id: UUID, strip: StripLayout) {
        guard let old = repository.layout(id: id, key: key) else { return }
        let isActive = repository.activeLayout(for: key)?.id == id
        // The layout is saved first: if the app quits between the two writes, memory never names zones that the
        // saved layout lacks.
        repository.setStrip(strip, ofLayout: id, key: key)
        if isActive, let area = screens.screens().first(where: { $0.key == key })?.axVisible {
            release(memory.remap(ZoneRemapper.byCoverage(old: old.root, new: strip.root, in: area)))
        }
        prune()
        if isActive { refresher?.refreshZones() }
        refresher?.restoreWindows()
    }

    func removeLayout(key: String, id: UUID) {
        if repository.activeLayout(for: key)?.id == id,
           let other = repository.layouts(for: key).first(where: { $0.id != id && !repository.isTaken(layout: $0.id, key: key) }) {
            activate(key: key, id: other.id)
        }
        repository.removeLayout(id: id, key: key)
        prune()
        refresher?.refreshZones()
    }

    /// Makes a layout active; the apps of all the old zones (those beyond the edges too) move to the new layout's default
    /// zone, except those that were in one of its zones before: they go back there.
    func activate(key: String, id: UUID) {
        guard let new = repository.layout(id: id, key: key) else { return }
        let old = repository.activeLayout(for: key)
        repository.activate(layout: id, key: key)
        if let old, old.id != id, let home = new.fallbackZoneID {
            let map = Dictionary(uniqueKeysWithValues: old.strip.zoneIDs.map { ($0, home) })
            release(memory.remap(map, preferred: Set(new.strip.zoneIDs)))
        }
        refresher?.refreshZones()
        refresher?.restoreWindows()
    }

    func deactivate(key: String) {
        repository.deactivate(key: key)
        refresher?.refreshZones()
        refresher?.restoreWindows()
    }

    func setGap(key: String, id: UUID, to gap: Double?) {
        repository.setGap(gap, ofLayout: id, key: key)
        refresher?.refreshZones()
        refresher?.restoreWindows()
    }

    func rename(key: String, id: UUID, to name: String) {
        repository.rename(layout: id, key: key, to: name)
    }

    func setDefaultZone(key: String, id: UUID, to zone: UUID?) {
        repository.setDefaultZone(zone, ofLayout: id, key: key)
    }

    /// The zones beyond the screens' edges are switched off: their apps go to the default zone of their layout.
    func moveOverflowAppsToDefaultZones() {
        var map: [UUID: UUID] = [:]
        for layout in repository.screens.values.flatMap(\.layouts) {
            guard let target = layout.fallbackZoneID else { continue }
            let beyond = layout.strip.zoneIDs.filter { !layout.root.leafIDs.contains($0) }
            beyond.forEach { map[$0] = target }
        }
        release(memory.remap(map))
        refresher?.refreshZones()
        refresher?.restoreWindows()
    }

    /// The zones beyond the screens' edges are switched on again: apps that left them when they were switched off go back
    /// (a slot remembers the zones it was in).
    func returnOverflowAppsToTheirZones() {
        var released: [CGWindowID] = []
        for layout in repository.screens.values.flatMap(\.layouts) {
            guard let home = layout.fallbackZoneID else { continue }
            let beyond = Set(layout.strip.zoneIDs).subtracting(layout.root.leafIDs)
            released += memory.remap([home: home], preferred: beyond)
        }
        release(released)
        refresher?.refreshZones()
        refresher?.restoreWindows()
    }

    // MARK: Displays

    /// Layouts stored under a display's old key (its desktop's system identifier, which changes whenever a display
    /// is plugged in or out) are kept under the key that tells the desktop by its position.
    func migrateKeys() {
        for screen in screens.screens() where repository.layouts(for: screen.key).isEmpty {
            let old = repository.legacyKeys(ofDisplay: screen.displayID)
            let pick = old.first { $0 == screen.legacyKey }
                ?? old.max { (Int($0.split(separator: "|").last ?? "") ?? 0) < (Int($1.split(separator: "|").last ?? "") ?? 0) }
            if let pick { repository.moveScreen(from: pick, to: screen.key) }
        }
    }

    /// A display that is gone leaves its apps in the default zone of the main screen's layout; one that came
    /// back gets them again (a slot remembers the zone it had).
    func displaysDidChange() {
        let current = screens.screens()
        let connected = Set(current.map(\.displayID))
        let before = knownDisplays
        knownDisplays = connected
        // The first look also adopts what a display left behind while the app was not running.
        guard before.isEmpty || before != connected else { return }

        if let main = current.first, let target = repository.activeLayout(for: main.key)?.fallbackZoneID {
            let orphans = repository.zoneIDs(ofDisplaysNotIn: connected)
            release(memory.remap(Dictionary(uniqueKeysWithValues: orphans.map { ($0, target) })))
        }
        let back = connected.subtracting(before)
        if !before.isEmpty, !back.isEmpty {
            let home = Set(current.filter { back.contains($0.displayID) }
                .compactMap { repository.activeLayout(for: $0.key) }.flatMap { $0.strip.zoneIDs })
            let everywhere = current.compactMap { repository.activeLayout(for: $0.key) }.flatMap { $0.strip.zoneIDs }
            release(memory.remap(Dictionary(uniqueKeysWithValues: everywhere.map { ($0, $0) }), preferred: home))
        }
        refresher?.restoreWindows()
    }

    func desktopsDidChange(on screens: [ScreenInfo]) {
        for screen in screens where screen.desktopCount > 0 {
            repository.forgetDesktops(ofDisplay: screen.displayID, after: screen.desktopCount)
        }
    }

    // MARK: Helpers

    /// Their slots now name new zones; let go of the live windows so they are re-attached there.
    private func release(_ windowIDs: [CGWindowID]) {
        windowIDs.forEach { coordinator.removeFromStack(window: $0) }
    }

    func prune() {
        let alive = repository.allZoneIDs
        coordinator.prune(keeping: alive)
        memory.prune(keepingZones: alive)
    }
}
