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
    let layoutApps: LayoutAppsService
    let launchAtLogin: LaunchAtLoginModel
    let updates: UpdatesModel
    let relauncher: AppRelaunching = WorkspaceAppRelauncher()
    let appCatalog: AppCatalog
    let activation: ActivationPolicyControlling
    let settingsNavigation: SettingsNavigation

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
        let windowManagerDefaults = UserDefaults(suiteName: "com.apple.WindowManager")
        coordinator.placementOnly = { windowManagerDefaults?.bool(forKey: "GloballyEnabled") ?? false }
        let stagePanels = StagePanels()
        let snapshots = ScreenCaptureWindowSnapshots()
        let slideStage = PanelSlideStage(screens: screens, panels: stagePanels)
        coordinator.carousel = ZoneCarousel(snapshots: snapshots, stage: slideStage,
                                            reduceMotion: { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion },
                                            background: { DispatchQueue.global(qos: .userInteractive).async(execute: $0) })
        coordinator.glide = WindowGlide(windows: windows, reduceMotion: { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion },
                                        background: { DispatchQueue.global(qos: .userInteractive).async(execute: $0) })
        let availability = WindowAvailability(windows: windows, screens: screens)
        let restorer = WindowRestorer(windows: windows, apps: apps, screens: screens, memory: memory, coordinator: coordinator,
                                      availability: availability, settings: settings)
        let viewport = StripViewport()
        let planner = ZonePlanner(layouts: repository, settings: settings, viewport: viewport)
        let engine = ZoneEngine(planner: planner,
                                coordinator: coordinator, restorer: restorer, screens: screens, windows: windows)
        let layouts = LayoutService(repository: repository, memory: memory, coordinator: coordinator, screens: screens)
        layouts.refresher = engine
        engine.displayHandler = layouts

        let closedMonitor = ClosedWindowMonitor(coordinator: coordinator, availability: availability, screens: screens)
        let iconFont = IconFont(brands: CDNBrandGlyphs(isEnabled: { [weak settings] in settings?.values.fetchBrandIcons ?? false }))
        let navigation = SettingsNavigation()
        let pill = PillPresenter(coordinator: coordinator, settings: settings, screens: screens, iconFont: iconFont) { zone in
            navigation.tab = .layouts
            let layout = repository.screens.values.flatMap(\.layouts).first { $0.strip.zoneIDs.contains(zone) }
            navigation.ordering = layout.map { OrderingTarget(layoutID: $0.id, zoneID: zone) }
            navigation.openSettings()
        }
        engine.add(presenter: pill)
        coordinator.onActivity = { [weak pill] zone in pill?.flash(zone: zone) }

        settings.onPlacementChanged = { [weak engine, weak settings] in
            if let settings { engine?.placementChanged(enabled: settings.values.placementEnabled) }
        }
        settings.onIgnoredAppsChanged = { [weak coordinator, weak engine] in
            coordinator?.releaseIgnoredApps()
            engine?.refreshZones()
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
        self.layoutApps = LayoutAppsService(memory: memory, coordinator: coordinator, apps: apps, refresher: engine,
                                              iconFont: iconFont, settings: settings, windows: windows)
        self.appCatalog = apps
        self.activation = activation
        self.settingsNavigation = navigation
        self.launchAtLogin = LaunchAtLoginModel(loginItem: SMAppServiceLoginItem())
        self.updates = UpdatesModel(
            currentVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?",
            checker: GitHubReleaseChecker(repository: "ffferitkartalll/paneflipapp"), installer: DiskImageUpdateInstaller())
        self.editor = EditorController(repository: repository, layouts: layouts, screens: screens, settings: settings)
        let snap = SnapDragController(windows: windows, screens: screens, coordinator: coordinator, settings: settings,
                                      keys: keys, overlay: SnapZoneOverlay(screens: screens))
        let shortcut: KeyShortcutListening = EventTapKeyShortcut { [settings] in
            let v = settings.values
            return [(KeyShortcut.cycle(reverse: false), v.nextWindowShortcut), (.cycle(reverse: true), v.previousWindowShortcut),
                    (.scroll(.right), v.scrollRightShortcut), (.scroll(.left), v.scrollLeftShortcut)]
                .compactMap { press, trigger in KeyChord(trigger).map { (press, $0) } }
        }
        let mover = WindowMover(windows: windows, background: { DispatchQueue.global(qos: .userInteractive).async(execute: $0) })
        let scroller = StripScroller(screens: screens, planner: planner, viewport: viewport,
                                     settings: settings, coordinator: coordinator, mover: mover, snapshots: snapshots,
                                     stage: PanelScrollStage(screens: screens, panels: stagePanels),
                                     metronome: DisplayLinkMetronome.start, refresher: engine,
                                     reduceMotion: { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion },
                                     isBusy: { coordinator.placementOnly() || screens.isMissionControlActive })
        coordinator.onFocusBeyondTheEdge = { [weak scroller] zone in scroller?.reveal(zone: zone) }
        let edgeScroller = EdgeScroller(listener: GlobalPointerMoves(), screens: screens, settings: settings, scroller: scroller) { delay, work in
            let item = DispatchWorkItem(block: work)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
            return item.cancel
        }
        settings.onOverflowZonesChanged = { [weak scroller, weak edgeScroller, weak layouts, weak engine, viewport, settings] in
            scroller?.settingDidChange()
            edgeScroller?.settingDidChange()
            guard !settings.values.overflowZonesEnabled else {
                layouts?.returnOverflowAppsToTheirZones()
                return
            }
            viewport.reset()
            layouts?.moveOverflowAppsToDefaultZones()
            engine?.refreshZones()
        }
        let launcher = AppLauncher(permissions: SystemPermissions(), screen: PermissionsWindowController(activation: activation)) {
            engine.start()
            closedMonitor.start()
            pill.start()
            snap.start()
            scroller.start()
            edgeScroller.start()
            shortcut.start { press in
                switch press {
                case .cycle(let reverse): coordinator.cycleFocusedZone(reverse: reverse)
                case .scroll(let edge): scroller.scroll(toward: edge)
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { slideStage.prepare() }
        }
        engine.onPermissionLost = { [weak launcher] in launcher?.recoverPermissions() }
        self.launcher = launcher
    }

    /// Checks permissions, then starts the services (immediately, or once the user has granted them).
    func start() {
        layouts.migrateKeys()
        layouts.displaysDidChange()   // remember the displays that are connected
        layouts.prune()   // drop remembered apps whose zone no longer exists in any layout
        launcher.launch()
    }
}
