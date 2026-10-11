import AppKit
import Foundation

/// Keeps the zones in step with the world: lays them out on the visible desktops, reacts to desktop and display
/// changes, and runs the periodic housekeeping. It coordinates; the work lives in its collaborators.
final class ZoneEngine: ZoneRefreshing {
    private let planner: ZonePlanner
    private let coordinator: StackCoordinator
    private let restorer: WindowRestorer
    private let screens: ScreenProviding
    private var presenters: [ZonePresenting] = []
    private var lastKeys: [String] = []
    private var timer: Timer?

    init(planner: ZonePlanner, coordinator: StackCoordinator, restorer: WindowRestorer, screens: ScreenProviding) {
        self.planner = planner
        self.coordinator = coordinator
        self.restorer = restorer
        self.screens = screens
    }

    func add(presenter: ZonePresenting) { presenters.append(presenter) }

    func start() {
        refreshZones()
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in self?.tick() }
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main) { [weak self] _ in self?.refreshZones() }
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in self?.refreshZones() }
    }

    // MARK: ZoneRefreshing

    func refreshZones() {
        let current = screens.screens()
        lastKeys = current.map(\.key)
        coordinator.apply(zones: planner.visibleZones(on: current))
        presenters.forEach { $0.zonesDidChange() }
    }

    func restoreWindows() { restorer.restore() }

    // MARK: Feature switches

    /// Placement switched on or off. Off: let go of every window (the memory stays) and hide the pills.
    func placementChanged(enabled: Bool) {
        if !enabled { coordinator.releaseAll() }
        refreshZones()
        if enabled { restorer.restore() }
    }

    /// Stacking switched on or off. Off: each zone keeps only its front window.
    func stackingChanged(enabled: Bool) {
        if !enabled { coordinator.enforceSingleApp() }
        presenters.forEach { $0.zonesDidChange() }
    }

    // MARK: Housekeeping

    private func tick() {
        if screens.screens().map(\.key) != lastKeys { refreshZones() }
        coordinator.syncTitles()
        coordinator.followFocus()
        restorer.restore()
    }
}
