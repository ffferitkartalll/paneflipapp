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

    func importLayout(for key: String, _ layout: NamedLayout) {
        repository.importLayout(layout, key: key)
    }

    func updateLayout(key: String, id: UUID, strip: StripLayout, animated: Bool) {
        guard let old = repository.layout(id: id, key: key) else { return }
        let isActive = repository.activeLayout(for: key)?.id == id
        // The layout is saved first: if the app quits between the two writes, memory never names zones that the
        // saved layout lacks.
        repository.setStrip(strip, ofLayout: id, key: key)
        if isActive {
            var map = screens.screens().first { $0.key == key }.map { ZoneRemapper.byCoverage(old: old.root, new: strip.root, in: $0.axVisible) } ?? [:]
            if let home = repository.layout(id: id, key: key)?.fallbackZoneID {
                map.merge(ZoneRemapper.beyondEdges(old: old.strip, new: strip, home: home)) { kept, _ in kept }
            }
            if !map.isEmpty { release(memory.remap(map)) }
        }
        prune()
        if isActive {
            coordinator.glidesPlacement = animated
            refresher?.refreshZones()
            coordinator.glidesPlacement = false
        }
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

    func setSpacing(key: String, id: UUID, gap: Double, edgeMargin: Double, minZoneSize: Double) {
        repository.setSpacing(gap: gap, edgeMargin: edgeMargin, minZoneSize: minZoneSize, ofLayout: id, key: key)
    }

    func setStartApp(key: String, id: UUID, bundleID: String, chosen: Bool) {
        repository.setStartApp(bundleID, chosen: chosen, ofLayout: id, key: key)
    }

    func setZoneName(key: String, id: UUID, zone: UUID, to name: String) {
        repository.setZoneName(name, ofZone: zone, inLayout: id, key: key)
    }

    func setZoneAspects(key: String, id: UUID, _ aspects: [UUID: ZoneAspect]) {
        repository.setZoneAspects(aspects, ofLayout: id, key: key)
    }

    func rename(key: String, id: UUID, to name: String) {
        repository.rename(layout: id, key: key, to: name)
    }

    func setDefaultZone(key: String, id: UUID, to zone: UUID?) {
        repository.setDefaultZone(zone, ofLayout: id, key: key)
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

    /// The windows of a display that is gone spread over the usable area of the first display and are in no zone; when the display comes
    /// back they return to the zones they were in, also when they were put in a zone of another display meanwhile (a slot remembers its home).
    func displaysDidChange() {
        let current = screens.screens()
        let connected = Set(current.map(\.displayID))
        let before = knownDisplays
        knownDisplays = connected
        guard before.isEmpty || before != connected else { return }

        // The windows of a display that is gone spread over the usable area of the first display, in no zone; their slots wait for the display.
        if let main = current.first {
            coordinator.displace(zones: repository.zoneIDs(ofDisplaysNotIn: connected), over: main.axVisible)
        }
        // Every zone of the displays that came back, whichever layout is active there.
        let home = repository.zoneIDs(ofDisplaysNotIn: before).subtracting(repository.zoneIDs(ofDisplaysNotIn: connected))
        if !before.isEmpty, !home.isEmpty { release(memory.returnHome(to: home)) }
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
