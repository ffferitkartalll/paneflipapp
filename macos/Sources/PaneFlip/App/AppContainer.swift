import AppKit
import PaneFlipCore
import SwiftUI

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
    let menuBar: MenuBarController

    private let launcher: AppLauncher
    private let memoryPressure: MemoryPressureWatch

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
        let capture = ScreenCaptureWindowSnapshots()
        let pictures = WindowPictureCache(now: { ProcessInfo.processInfo.systemUptime })
        // A zone's windows are photographed ahead of time (PictureKeeper) and the pictures are reused; a window in front is live, so its picture counts only for a moment.
        let snapshots = CachedWindowSnapshots(inner: capture, cache: pictures,
                                              zoneSize: { [unowned coordinator] id in coordinator.stack(containing: id).flatMap { $0.isFloating ? nil : $0.rect.size } },
                                              isFront: { [unowned coordinator] id in coordinator.stack(containing: id).map { $0.activeID == id || $0.shownID == id } ?? false })
        coordinator.pictures = pictures
        let keeper = PictureKeeper(coordinator: coordinator, snapshots: capture, cache: pictures,
                                   canCapture: { CGPreflightScreenCaptureAccess() },
                                   reduceMotion: { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion },
                                   now: { ProcessInfo.processInfo.systemUptime })
        coordinator.onFocusLeft = { [weak keeper] in keeper?.windowLeftFocus($0) }
        coordinator.onMotionEnded = { [weak keeper] in keeper?.motionEnded() }
        self.memoryPressure = MemoryPressureWatch { pictures.removeAll() }
        let slideStage = PanelSlideStage(screens: screens, panels: stagePanels)
        coordinator.carousel = ZoneCarousel(snapshots: snapshots, stage: slideStage,
                                            reduceMotion: { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion },
                                            background: { DispatchQueue.global(qos: .userInteractive).async(execute: $0) })
        coordinator.snapshots = snapshots
        let focusQueue = DispatchQueue(label: "PaneFlip.focus", qos: .userInteractive)
        coordinator.focusQueue = { focusQueue.async(execute: $0) }
        coordinator.floatStage = PanelFloatStage(screens: screens, panels: stagePanels)
        coordinator.reduceMotion = { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }
        coordinator.glide = WindowGlide(windows: windows, reduceMotion: { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion },
                                        background: { DispatchQueue.global(qos: .userInteractive).async(execute: $0) })
        let availability = WindowAvailability(windows: windows, screens: screens)
        let restorer = WindowRestorer(windows: windows, apps: apps, screens: screens, memory: memory, coordinator: coordinator,
                                      availability: availability, settings: settings)
        restorer.background = { focusQueue.async(execute: $0) }
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
        let layoutApps = LayoutAppsService(memory: memory, coordinator: coordinator, apps: apps, refresher: engine, iconFont: iconFont, settings: settings, windows: windows)
        let island = MenuBarIsland(coordinator: coordinator, repository: repository, settings: settings, screens: screens, screensNow: { [unowned engine] in engine.lastScreens }, planner: planner, viewport: viewport, iconFont: iconFont,
                                   memory: memory, apps: apps, openApp: { layoutApps.open(apps: [$0]) })
        engine.add(presenter: island)
        coordinator.onActivity = { [weak island] _ in island?.windowsDidChange() }
        coordinator.onFocusMoved = { [weak island] in island?.focusDidMove() }
        coordinator.onWindowScrub = { [weak island] zone, fraction in island?.windowsScrubbed(zone: zone, by: fraction) }

        settings.onPlacementChanged = { [weak engine, weak settings] in
            if let settings { engine?.placementChanged(enabled: settings.values.placementEnabled) }
        }
        settings.onIgnoredAppsChanged = { [weak coordinator, weak engine] in
            coordinator?.releaseIgnoredApps()
            engine?.refreshZones()
        }

        self.settings = settings
        self.layoutRepository = repository
        self.screens = screens
        self.windows = windows
        self.layouts = layouts
        self.engine = engine
        self.layoutApps = layoutApps
        self.appCatalog = apps
        self.activation = activation
        self.settingsNavigation = navigation
        self.launchAtLogin = LaunchAtLoginModel(loginItem: SMAppServiceLoginItem())
        self.updates = UpdatesModel(
            currentVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?",
            checker: GitHubReleaseChecker(repository: "ffferitkartalll/paneflipapp"), installer: DiskImageUpdateInstaller())
        let editor = EditorController(repository: repository, layouts: layouts, screens: screens, settings: settings)
        self.editor = editor
        island.isSuppressed = { [unowned editor] in editor.isShown }
        let menuContent = MenuContent(repository: repository, layouts: layouts, screens: screens, settings: settings, apps: layoutApps, editor: editor,
                                                       openSettings: SettingsWindowOpener.open)
        // A menu does not take the app's language by itself: the one the app started with, as the scenes have it.
        let menu = NSHostingMenu(rootView: menuContent.environment(\.locale, Locale(identifier: Bundle.main.preferredLocalizations.first ?? "en")))
        self.menuBar = MenuBarController(settings: settings, menu: menu)
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
        // The tap asks this for every scroll event (momentum included): a window list each time would stall the main thread, so the answer is kept for a moment.
        var missionControlAsked = (at: Date.distantPast, active: false)
        let missionControl: () -> Bool = { [screens] in
            if Date().timeIntervalSince(missionControlAsked.at) > 0.3 { missionControlAsked = (Date(), screens.isMissionControlActive) }
            return missionControlAsked.active
        }
        let scrollSwitch: ScrollSwitchListening = EventTapScrollSwitch(gain: { [settings] in SystemTrackpadSpeed().scrollGain(multiplier: settings.values.trackpadSpeed) },
                                                       twoFingers: { [settings] in settings.values.trackpadMethod == .keysAndTwoFingers },
                                                       overIsland: { [settings, coordinator, editor, island] in
            // The cheap test first: nearly every scroll event of the system is not over the island.
            guard let target = island.scrollTarget(at: NSEvent.mouseLocation) else { return nil }
            let v = settings.values
            guard v.placementEnabled, !coordinator.placementOnly(), !editor.isShown,
                  target != .strip || v.overflowZonesEnabled else { return nil }
            // Asked last, only over the island: it costs a window list, and every scroll event of the system comes through here.
            return missionControl() ? nil : target
        }) { [settings, keys, coordinator, editor] in
            let v = settings.values
            guard v.placementEnabled, !coordinator.placementOnly(), !editor.isShown else { return nil }
            let strip = v.overflowZonesEnabled && v.stripScrollKeys.isHeld(using: keys)
            let windows = v.windowScrollKeys.isHeld(using: keys)
            // The keys of the one are those of the other and more (Command, Option, Control against Option and Control): the longer wins.
            if strip && (!windows || v.stripScrollKeys.keys.count >= v.windowScrollKeys.keys.count) { return missionControl() ? nil : .strip }
            let target: ScrollSwitchTarget? = windows ? .windows : nil
            // Asked only once a key is held: it costs a window list. Nothing of ours moves under Mission Control or App Exposé.
            return target != nil && missionControl() ? nil : target
        }
        let mover = WindowMover(windows: windows, background: { DispatchQueue.global(qos: .userInteractive).async(execute: $0) })
        let scroller = StripScroller(screens: screens, planner: planner, viewport: viewport,
                                     settings: settings, coordinator: coordinator, mover: mover, snapshots: snapshots,
                                     stage: PanelScrollStage(screens: screens, panels: stagePanels),
                                     metronome: DisplayLinkMetronome.start, refresher: engine,
                                     reduceMotion: { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion },
                                     isBusy: { coordinator.placementOnly() || editor.isShown || missionControl() })
        let scrollSwitchHandler = ScrollSwitchHandler(coordinator: coordinator, scroller: scroller, screens: screens) { [settings, coordinator, editor] target in
            let v = settings.values
            return v.placementEnabled && !coordinator.placementOnly() && !editor.isShown && (target != .strip || v.overflowZonesEnabled)
                && !missionControl()
        }
        let fingerSwipes: ScrollSwitchListening = MultitouchSwipes(gain: { [settings] in SystemTrackpadSpeed().scrollGain(multiplier: settings.values.trackpadSpeed) },
                                                       isOn: { [settings] in settings.values.trackpadMethod == .threeAndFourFingers })
        coordinator.holdsTheFocus = { NSRunningApplication.current.isActive }   // read off the main thread too: not NSApp
        let zoneFlash = ZoneFlash(screens: screens, reduceMotion: { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion })
        coordinator.flashZone = { zoneFlash.flash($0) }
        coordinator.onFocusBeyondTheEdge = { [weak scroller] zone in scroller?.reveal(zone: zone) }
        coordinator.onReachBeyondTheEdge = { [weak scroller] zone, standsAt in scroller?.reveal(zone: zone, standsAt: standsAt) ?? false }
        scroller.onFollow = { [weak island] screen, offset in island?.follow(on: screen, offset: offset) }
        scroller.onGlide = { [weak island] screen, from, to in island?.glide(on: screen, from: from, to: to) }
        // A zone a shortcut asked for beyond the edge is focused once the scroll is over.
        scroller.onRest = {
            coordinator.finishFocusBeyondTheEdge()
            coordinator.onMotionEnded?()
        }
        settings.onOverflowZonesChanged = { [weak scroller, weak layouts, weak engine, viewport, settings] in
            scroller?.settingDidChange()
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
            island.start()
            snap.start()
            scroller.start()
            scrollSwitch.start(onEvent: scrollSwitchHandler.handle)
            fingerSwipes.start(onEvent: scrollSwitchHandler.handle)
            shortcut.start { press in
                switch press {
                case .cycle(let reverse): coordinator.cycleFocusedZone(reverse: reverse)
                case .scroll(let edge): scroller.scroll(toward: edge)
                case .focusZone(let direction): coordinator.focusZone(toward: direction)
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { slideStage.prepare() }
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) { keeper.motionEnded() }   // the first pictures, once the windows have settled in their zones
        }
        engine.onPermissionLost = { [weak launcher] in launcher?.recoverPermissions() }
        self.launcher = launcher
    }

    /// Checks permissions, then starts the services (immediately, or once the user has granted them).
    func start() {
        menuBar.install()
        layouts.migrateKeys()
        layouts.displaysDidChange()   // remember the displays that are connected
        layouts.prune()   // drop remembered apps whose zone no longer exists in any layout
        launcher.launch()
    }
}
