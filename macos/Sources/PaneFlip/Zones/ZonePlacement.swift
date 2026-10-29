import CoreGraphics
import Foundation
import PaneFlipCore

/// Sends the focused window to another zone by keys, through the island: the modifier keys open the island with the window's own zone lit (or the screen's
/// default zone, for a window in no zone) in a colour of its own; the arrow keys move the light to another zone, Return puts the window there, Escape lets it be.
final class ZonePlacement {
    private let repository: LayoutRepository
    private let screens: ScreenProviding
    private let windows: WindowSystem
    private let coordinator: StackCoordinator
    private let settings: AppSettings
    private let island: ZonePicking
    private let isBlocked: () -> Bool
    /// The window being sent, the zone it is in (nil: none), and the zone lit now.
    private var choice: (window: WindowRef, own: UUID?, lit: UUID)?

    init(repository: LayoutRepository, screens: ScreenProviding, windows: WindowSystem, coordinator: StackCoordinator, settings: AppSettings, island: ZonePicking,
         isBlocked: @escaping () -> Bool) {
        self.repository = repository
        self.screens = screens
        self.windows = windows
        self.coordinator = coordinator
        self.settings = settings
        self.island = island
        self.isBlocked = isBlocked
    }

    var isChoosing: Bool { choice != nil }

    func handle(_ event: PlacementEvent) {
        switch event {
        case .chord: begin()
        case .key(.move(let direction)): move(direction)
        case .key(.confirm): confirm()
        case .key(.cancel): finish()
        case .key(.remove): remove()
        }
    }

    private func begin() {
        guard choice == nil, !isBlocked(), settings.values.placementEnabled, !coordinator.placementOnly(), let window = windows.focusedWindow(),
              let layout = layout(of: window) else { return }
        let own = coordinator.stack(containing: window.id)?.id
        guard let start = own ?? layout.fallbackZoneID, coordinator.stacks[start] != nil, island.startPicking(zone: start) else { return }
        choice = (window, own, start)
    }

    private func move(_ direction: ZoneDirection) {
        guard let choice, let next = island.zone(toward: direction, from: choice.lit) else { return }
        self.choice?.lit = next
        island.pick(next)
    }

    private func confirm() {
        guard let choice else { return }
        finish()
        // A zone that is not laid out now has no place to send to; the window's own zone is where it already is.
        guard choice.lit != choice.own, coordinator.stacks[choice.lit] != nil else { return }
        coordinator.snap(choice.window, into: choice.lit)
        coordinator.revealSent(choice.window, in: choice.lit)
    }

    /// A window in a zone is taken out of it, to the middle of its screen; a window in none has nothing to be taken out of.
    private func remove() {
        guard let choice, choice.own != nil, let area = place(of: choice.window)?.screen.axVisible else { return }
        finish()
        coordinator.remove(choice.window, centredIn: area)
    }

    private func finish() {
        guard choice != nil else { return }
        choice = nil
        island.stopPicking()
    }

    private func layout(of window: WindowRef) -> NamedLayout? { place(of: window)?.layout }

    /// The screen the window is on and its layout: the one its zone belongs to, or the one under the window.
    private func place(of window: WindowRef) -> (screen: ScreenInfo, layout: NamedLayout)? {
        let all = screens.screens()
        if let held = coordinator.stack(containing: window.id) {
            return all.lazy.compactMap { screen in self.repository.activeLayout(for: screen.key).map { (screen, $0) } }.first { $0.1.zoneIDs.contains(held.id) }
        }
        guard let frame = windows.frame(of: window) else { return nil }
        let middle = CGPoint(x: frame.midX, y: frame.midY)
        return all.first { screens.flip($0.cocoaFrame).contains(middle) }.flatMap { screen in self.repository.activeLayout(for: screen.key).map { (screen, $0) } }
    }
}
