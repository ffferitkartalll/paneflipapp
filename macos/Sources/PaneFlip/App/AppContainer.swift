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
        coordinator.snapshots = snapshots
        coordinator.floatStage = PanelFloatStage(screens: screens, panels: stagePanels)
        coordinator.reduceMotion = { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }
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
            let layout = repository.screens.values.flatMap(\.layouts).first { $0.zoneIDs.contains(zone) }
            navigation.ordering = layout.map { OrderingTarget(layoutID: $0.id, zoneID: zone) }
            navigation.openSettings()
        }
        engine.add(presenter: pill)
        let island = MenuBarIsland(coordinator: coordinator, repository: repository, settings: settings, screens: screens, screensNow: { [unowned engine] in engine.lastScreens }, planner: planner, viewport: viewport)
        engine.add(presenter: island)
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
        let editor = EditorController(repository: repository, layouts: layouts, screens: screens, settings: settings)
        self.editor = editor
        let snap = SnapDragController(windows: windows, screens: screens, coordinator: coordinator, settings: settings,
                                      keys: keys, overlay: SnapZoneOverlay(screens: screens), island: island)
        let shortcut: KeyShortcutListening = EventTapKeyShortcut { [settings] in
            let v = settings.values
            var all: [(KeyShortcut, SnapTrigger)] = [(.cycle(reverse: false), v.nextWindowShortcut), (.cycle(reverse: true), v.previousWindowShortcut),
                                                     (.scroll(.right), v.scrollRightShortcut), (.scroll(.left), v.scrollLeftShortcut)]
            if v.zoneNavigationEnabled {
                all += [(.focusZone(.up), v.zoneUpShortcut), (.focusZone(.left), v.zoneLeftShortcut),
                        (.focusZone(.down), v.zoneDownShortcut), (.focusZone(.right), v.zoneRightShortcut)]
            }
            return all.compactMap { press, trigger in KeyChord(trigger).map { (press, $0) } }
        }
        let scrollSwitch: ScrollSwitchListening = EventTapScrollSwitch(gain: { [settings] in SystemTrackpadSpeed().scrollGain(multiplier: settings.values.trackpadSpeed) },
                                                       twoFingers: { [settings] in settings.values.trackpadMethod == .keysAndTwoFingers }) { [settings, keys, coordinator, screens, editor] in
            let v = settings.values
            guard v.placementEnabled, !coordinator.placementOnly(), !editor.isShown else { return nil }
            let strip = v.overflowZonesEnabled && v.stripScrollKeys.isHeld(using: keys)
            let windows = v.stackingEnabled && v.windowScrollKeys.isHeld(using: keys)
            // The keys of the one are those of the other and more (Command, Option, Control against Option and Control): the longer wins.
            if strip && (!windows || v.stripScrollKeys.keys.count >= v.windowScrollKeys.keys.count) { return screens.isMissionControlActive ? nil : .strip }
            let target: ScrollSwitchTarget? = windows ? .windows : nil
            // Asked only once a key is held: it costs a window list. Nothing of ours moves under Mission Control or App Exposé.
            return target != nil && screens.isMissionControlActive ? nil : target
        }
        let mover = WindowMover(windows: windows, background: { DispatchQueue.global(qos: .userInteractive).async(execute: $0) })
        let scroller = StripScroller(screens: screens, planner: planner, viewport: viewport,
                                     settings: settings, coordinator: coordinator, mover: mover, snapshots: snapshots,
                                     stage: PanelScrollStage(screens: screens, panels: stagePanels),
                                     metronome: DisplayLinkMetronome.start, refresher: engine,
                                     reduceMotion: { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion },
                                     isBusy: { coordinator.placementOnly() || editor.isShown || screens.isMissionControlActive })
        let scrollSwitchHandler = ScrollSwitchHandler(coordinator: coordinator, scroller: scroller, screens: screens) { [settings, coordinator, screens, editor] target in
            let v = settings.values
            return v.placementEnabled && !coordinator.placementOnly() && !editor.isShown && (target == .strip ? v.overflowZonesEnabled : v.stackingEnabled)
                && !screens.isMissionControlActive
        }
        let fingerSwipes: ScrollSwitchListening = MultitouchSwipes(gain: { [settings] in SystemTrackpadSpeed().scrollGain(multiplier: settings.values.trackpadSpeed) },
                                                       isOn: { [settings] in settings.values.trackpadMethod == .threeAndFourFingers })
        let mouseSwipes: ScrollSwitchListening = MouseButtonSwipes(
            gain: { [settings] in SystemTrackpadSpeed().scrollGain(multiplier: settings.values.trackpadSpeed) },
            canBegin: { [settings, coordinator, screens, editor] in
                let v = settings.values
                return v.placementEnabled && v.stackingEnabled && v.mouseButtonSwipe && !editor.isShown && coordinator.canScrubWindows(at: screens.pointerAX)
                    && !screens.isMissionControlActive
            })
        coordinator.holdsTheFocus = { NSRunningApplication.current.isActive }   // read off the main thread too: not NSApp
        let zoneFlash = ZoneFlash(screens: screens, reduceMotion: { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion })
        coordinator.flashZone = { zoneFlash.flash(from: $0, to: $1) }
        coordinator.onFocusBeyondTheEdge = { [weak scroller] zone in scroller?.reveal(zone: zone) }
        coordinator.onReachBeyondTheEdge = { [weak scroller] zone, standsAt in scroller?.reveal(zone: zone, standsAt: standsAt) }
        let edgeScroller = EdgeScroller(listener: GlobalPointerMoves(), screens: screens, settings: settings, scroller: scroller)
        // After the edge scroller took the hook: a zone a shortcut asked for beyond the edge is focused once the scroll is over.
        scroller.onFollow = { [weak island] screen, offset in island?.follow(on: screen, offset: offset) }
        scroller.onGlide = { [weak island] screen, from, to in island?.glide(on: screen, from: from, to: to) }
        let afterEdgeScroll = scroller.onRest
        scroller.onRest = { afterEdgeScroll?(); coordinator.finishFocusBeyondTheEdge() }
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
            island.start()
            snap.start()
            scroller.start()
            edgeScroller.start()
            scrollSwitch.start(onEvent: scrollSwitchHandler.handle)
            fingerSwipes.start(onEvent: scrollSwitchHandler.handle)
            mouseSwipes.start(onEvent: scrollSwitchHandler.handle)
            shortcut.start { press in
                switch press {
                case .cycle(let reverse): coordinator.cycleFocusedZone(reverse: reverse)
                case .scroll(let edge): scroller.scroll(toward: edge)
                case .focusZone(let direction): coordinator.focusZone(toward: direction)
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
