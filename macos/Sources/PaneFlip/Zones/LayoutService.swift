import CoreGraphics
import Foundation
import PaneFlipCore

/// Changes layouts and carries the consequences through: the apps of vanished zones move to the zones that cover
/// them, memory is pruned, and the zones are laid out again.
final class LayoutService: LayoutManaging {
    private let repository: LayoutRepository
    private let memory: StackMemory
    private let coordinator: StackCoordinator
    private let screens: ScreenProviding
    weak var refresher: ZoneRefreshing?

    init(repository: LayoutRepository, memory: StackMemory, coordinator: StackCoordinator, screens: ScreenProviding) {
        self.repository = repository
        self.memory = memory
        self.coordinator = coordinator
        self.screens = screens
    }

    @discardableResult
    func addLayout(for key: String) -> NamedLayout {
        let number = repository.layouts(for: key).count + 1
        let layout = repository.addLayout(for: key, named: String(localized: "Layout \(number)"))
        if repository.activeLayout(for: key)?.id == layout.id { refresher?.refreshZones() }
        return layout
    }

    func updateLayout(key: String, id: UUID, root: LayoutNode) {
        guard let old = repository.layout(id: id, key: key) else { return }
        let isActive = repository.activeLayout(for: key)?.id == id
        // The layout is saved first: if the app quits between the two writes, memory never names zones that the
        // saved layout lacks.
        repository.setRoot(root, ofLayout: id, key: key)
        if isActive, let area = screens.screens().first(where: { $0.key == key })?.axVisible {
            release(memory.remap(ZoneRemapper.byCoverage(old: old.root, new: root, in: area)))
        }
        prune()
        if isActive { refresher?.refreshZones() }
        refresher?.restoreWindows()
    }

    func removeLayout(key: String, id: UUID) {
        if repository.activeLayout(for: key)?.id == id,
           let other = repository.layouts(for: key).first(where: { $0.id != id }) {
            activate(key: key, id: other.id)
        }
        repository.removeLayout(id: id, key: key)
        prune()
        refresher?.refreshZones()
    }

    /// Makes a layout active; the apps of the old zones move over to the new ones by position.
    func activate(key: String, id: UUID) {
        guard let new = repository.layout(id: id, key: key) else { return }
        let old = repository.activeLayout(for: key)
        repository.activate(layout: id, key: key)
        if let old, old.id != id {
            // A slot goes back to the zone it had in this layout before, if it had one.
            release(memory.remap(ZoneRemapper.byOrder(old: old.root, new: new.root), preferred: Set(new.root.leafIDs)))
        }
        refresher?.refreshZones()
        refresher?.restoreWindows()
    }

    func rename(key: String, id: UUID, to name: String) {
        repository.rename(layout: id, key: key, to: name)
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
