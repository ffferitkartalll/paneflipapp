import AppKit
import PaneFlipCore

/// The composition root: builds every object once, hands each its collaborators, and wires the few callbacks.
/// Nothing else in the app reaches for a global.
final class AppContainer {
    // Domain
    let settings: AppSettings
    let layoutRepository: LayoutRepository

    // Platform
    let screens: ScreenProviding
    let windows: WindowSystem

    // Services
    let layouts: LayoutService
    let engine: ZoneEngine
    let editor: EditorController
    let launchAtLogin: LaunchAtLoginModel
    let activation: ActivationPolicyControlling

    private let launcher: AppLauncher

    init() {
        let documents = JSONFileStore()
        let settings = AppSettings(storage: UserDefaultsSettingsStorage())
        let repository = LayoutRepository(store: documents)
        let memory = StackMemory(store: documents)

        let screens = CGSScreenProvider()
        let windows = AXWindowSystem(screens: screens)
        let apps = WorkspaceAppCatalog()
        let keys = HardwareKeyState()
        let activation = AppKitActivationPolicyController()

        let coordinator = StackCoordinator(windows: windows, memory: memory, settings: settings, apps: apps)
        let availability = WindowAvailability(windows: windows, screens: screens)
        let restorer = WindowRestorer(windows: windows, apps: apps, memory: memory, coordinator: coordinator,
                                      availability: availability, settings: settings)
        let engine = ZoneEngine(planner: ZonePlanner(layouts: repository, settings: settings),
                                coordinator: coordinator, restorer: restorer, screens: screens, windows: windows)
        let layouts = LayoutService(repository: repository, memory: memory, coordinator: coordinator, screens: screens)
        layouts.refresher = engine

        let closedMonitor = ClosedWindowMonitor(coordinator: coordinator, availability: availability, screens: screens)
        let pill = PillPresenter(coordinator: coordinator, settings: settings, screens: screens,
                                 reorder: PillReorderController(coordinator: coordinator, settings: settings))
        engine.add(presenter: pill)
        coordinator.onActivity = { [weak pill] zone in pill?.flash(zone: zone) }

        settings.onPlacementChanged = { [weak engine, weak settings] in
            if let settings { engine?.placementChanged(enabled: settings.values.placementEnabled) }
        }
        settings.onStackingChanged = { [weak engine, weak settings] in
            if let settings { engine?.stackingChanged(enabled: settings.values.stackingEnabled) }
        }

        self.settings = settings
        self.layoutRepository = repository
        self.screens = screens
        self.windows = windows
        self.layouts = layouts
        self.engine = engine
        self.activation = activation
        self.launchAtLogin = LaunchAtLoginModel(loginItem: SMAppServiceLoginItem())
        self.editor = EditorController(repository: repository, layouts: layouts, screens: screens, settings: settings)
        let snap = SnapDragController(windows: windows, screens: screens, coordinator: coordinator, settings: settings,
                                      keys: keys, overlay: SnapZoneOverlay(screens: screens))
        let launcher = AppLauncher(permissions: SystemPermissions(), screen: PermissionsWindowController(activation: activation)) {
            engine.start()
            closedMonitor.start()
            pill.start()
            snap.start()
        }
        engine.onPermissionLost = { [weak launcher] in launcher?.recoverPermissions() }
        self.launcher = launcher
    }

    /// Checks permissions, then starts the services (immediately, or once the user has granted them).
    func start() {
        layouts.prune()   // drop remembered apps whose zone no longer exists in any layout
        launcher.launch()
    }
}
