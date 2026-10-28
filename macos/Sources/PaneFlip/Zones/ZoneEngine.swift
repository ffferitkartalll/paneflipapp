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
    /// Counts the bursts of an app starting or coming to the front (key 0: no app in particular): the looks of an earlier burst of the same key give way to
    /// those of the last.
    private var restoreBursts: [pid_t: Int] = [:]

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
            // Only the app that came is looked at: asking every app with a zone for its windows at each switch held the main thread for long.
            workspace.addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
                self?.scheduleRestore(onlyApp: (note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?.processIdentifier)
            }
        }
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
                self?.displaysChanged()
            }
        scheduleRestore()
    }

    // MARK: ZoneRefreshing

    /// After a display was unplugged nothing is moved until the Dock has landed on a remaining display (however long that takes; it is looked at every 0.1 s, every 0.5 s after 3 s): then the windows of the display
    /// that is gone spread over the usable area, once. The system itself moves them at once; that cannot be held back.
    private var waitingForDock = false

    private func displaysChanged(waited: Int = 0) {
        guard waited > 0 || !waitingForDock else { return }   // a wait is already running
        if !screens.isDockSettled {
            waitingForDock = true
            DispatchQueue.main.asyncAfter(deadline: .now() + (waited < 30 ? 0.1 : 0.5)) { [weak self] in self?.displaysChanged(waited: waited + 1) }
            return
        }
        waitingForDock = false
        displayHandler?.displaysDidChange()
        refreshZones()
        scheduleRestore()
    }

    func refreshZones() {
        guard !waitingForDock else { return }
        let current = screens.screens()
        lastSignatures = current.map(\.layoutSignature)
        lastScreens = current
        displayHandler?.desktopsDidChange(on: current)
        coordinator.apply(plan: planner.plan(on: current))
        presenters.forEach { $0.zonesDidChange() }
    }

    func restoreWindows() { restorer.restore() }

    // MARK: Feature switches

    /// Placement switched on or off. Off: let go of every window (the memory stays) and hide the island.
    func placementChanged(enabled: Bool) {
        if !enabled { coordinator.releaseAll() }
        refreshZones()
        if enabled { restorer.restore() }
    }

    // MARK: Housekeeping

    /// A freshly started app needs a moment to create its windows, so look now and again shortly after.
    private func scheduleRestore(onlyApp pid: pid_t? = nil) {
        let key = pid ?? 0
        restoreBursts[key, default: 0] += 1
        let burst = restoreBursts[key]!
        for delay in [0.0, 0.7, 2.0] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in self?.restore(burst: burst, key: key, onlyApp: pid) }
        }
    }

    /// One look at the apps' windows for a burst. Every window that a slide brings forward brings its app to the front, which asks for a look; the
    /// look asks every app with a zone for its windows (a stall of up to several hundred ms on the main thread), so while windows move it waits
    /// (a few seconds at most) and the look is made once, when they have come to rest.
    private func restore(burst: Int, key: pid_t, onlyApp pid: pid_t?, waited: Int = 0) {
        guard restoreBursts[key] == burst, !waitingForDock else { return }
        if coordinator.isMoving, waited < 40 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in self?.restore(burst: burst, key: key, onlyApp: pid, waited: waited + 1) }
            return
        }
        if let pid { restorer.restoreAfterListing(app: pid) } else { restorer.restore() }
    }

    private func tick() {
        guard windows.isTrusted else { return onPermissionLost?() ?? () }
        guard !coordinator.isMoving, !waitingForDock else { return }   // the windows are being moved; asking them now only slows the scroll
        if screens.screens().map(\.layoutSignature) != lastSignatures { refreshZones() }
        coordinator.syncTitles()
        coordinator.followFocus()
        restorer.restoreFrontmost()
    }
}
