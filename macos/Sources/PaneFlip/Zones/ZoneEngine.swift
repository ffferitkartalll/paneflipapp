import AppKit
import Foundation

/// Keeps the zones in step with the world: lays them out on the visible desktops, reacts to desktop and display
/// changes, and runs the periodic housekeeping. It coordinates; the work lives in its collaborators.
final class ZoneEngine: ZoneRefreshing {
    /// Called on every tick while the Accessibility permission is missing (the owner decides what to show).
    var onPermissionLost: (() -> Void)?
    /// Told first when displays were plugged in or out.
    weak var displayHandler: DisplayChangeHandling?

    private let planner: ZonePlanner
    private let coordinator: StackCoordinator
    private let restorer: WindowRestorer
    private let screens: ScreenProviding
    private let windows: WindowSystem
    private var presenters: [ZonePresenting] = []
    private var lastSignatures: [String] = []
    /// The displays as seen at the last look (see `refreshZones`): for those who need them as often and must not ask the Dock again.
    private(set) var lastScreens: [ScreenInfo] = []
    private var timer: Timer?

    init(planner: ZonePlanner, coordinator: StackCoordinator, restorer: WindowRestorer,
         screens: ScreenProviding, windows: WindowSystem) {
        self.planner = planner
        self.coordinator = coordinator
        self.restorer = restorer
        self.screens = screens
        self.windows = windows
    }

    func add(presenter: ZonePresenting) { presenters.append(presenter) }

    func start() {
        refreshZones()
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in self?.tick() }

        let workspace = NSWorkspace.shared.notificationCenter
        workspace.addObserver(forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.refreshZones()
            self?.scheduleRestore()
        }
        // A floating zone follows the focus: look at once when another app comes to the front, not at the next tick.
        workspace.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] _ in
            self?.coordinator.followFocus()
        }
        // A remembered app comes back when it starts, is shown again or is brought to the front.
        for name in [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didActivateApplicationNotification,
                     NSWorkspace.didUnhideApplicationNotification] {
            workspace.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in self?.scheduleRestore() }
        }
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
                self?.displayHandler?.displaysDidChange()
                self?.refreshZones()
                self?.scheduleRestore()
            }
        scheduleRestore()
    }

    // MARK: ZoneRefreshing

    func refreshZones() {
        let current = screens.screens()
        lastSignatures = current.map(\.layoutSignature)
        lastScreens = current
        displayHandler?.desktopsDidChange(on: current)
        coordinator.apply(plan: planner.plan(on: current))
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

    /// A freshly started app needs a moment to create its windows, so look now and again shortly after.
    private func scheduleRestore() {
        for delay in [0.0, 0.7, 2.0] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in self?.restorer.restore() }
        }
    }

    private func tick() {
        guard windows.isTrusted else { return onPermissionLost?() ?? () }
        guard !coordinator.isScrolling else { return }   // the windows are being moved; asking them now only slows the scroll
        if screens.screens().map(\.layoutSignature) != lastSignatures { refreshZones() }
        coordinator.syncTitles()
        coordinator.followFocus()
        restorer.restoreFrontmost()
    }
}
