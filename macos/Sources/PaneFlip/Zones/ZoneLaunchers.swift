import AppKit
import PaneFlipCore
import SwiftUI

/// Shows a launcher over every empty zone that the layout editor made one (`NamedLayout.launcherZones`), while the pointer rests over it in ordinary use. It is a panel of its own
/// with the zone's size that fades in and out, in place. It never shows while anything else is going on (`isQuiet`: a window is dragged, a grid or the island
/// is open, windows move, a key is held), while Mission Control or the layout editor is open, or once a window is in the zone, and not while a window of any app is under the pointer (only the wallpaper counts: `isPointerOverWallpaper`).
/// The pointer is only compared with the zones' rectangles and the system's window list: no other app is asked.
final class ZoneLaunchers: ZonePresenting {
    private let coordinator: StackCoordinator
    private let screens: ScreenProviding
    private let launcherZones: () -> Set<UUID>
    /// Nothing else is going on: no grid or island open (set by `AppContainer`, where they are made).
    var isQuiet: () -> Bool = { true }
    private let apps: LayoutAppsEditing
    /// The cards of a zone's grid, as the island makes them.
    private let cards: ZoneCardSource
    private let catalog: AppCatalog
    private let installed: InstalledAppListing
    private let ignored: () -> Set<String>
    private var panels: [UUID: NSPanel] = [:]
    private var models: [UUID: ZoneLauncherModel] = [:]
    private var monitors: [Any] = []
    private var timer: Timer?
    /// A mouse button went down in another app (a window is being dragged, a menu is used): nothing shows until it is up.
    private var pressedElsewhere = false
    /// Every installed app, read once, off the main thread, when the first launcher is shown.
    private var everyApp: [InstalledApp]?
    private var reading = false
    private var readAt: Date?
    /// The glyphs, shared by every zone's launcher and made a few at a time before the first launcher shows (making one is slow enough to stutter a scroll).
    private var glyphs: [String: NSImage] = [:]
    private static let movement = Animation.easeOut(duration: 0.25)

    /// Mission Control or the layout editor is open: no launchers until it is closed.
    var isCovered = false { didSet { if isCovered != oldValue { refresh() } } }

    init(coordinator: StackCoordinator, screens: ScreenProviding, launcherZones: @escaping () -> Set<UUID>, apps: LayoutAppsEditing, cards: ZoneCardSource,
         catalog: AppCatalog, installed: InstalledAppListing, ignored: @escaping () -> Set<String>) {
        self.coordinator = coordinator
        self.screens = screens
        self.launcherZones = launcherZones
        self.apps = apps
        self.cards = cards
        self.catalog = catalog
        self.installed = installed
        self.ignored = ignored
    }

    func start() {
        let down: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        monitors = [
            NSEvent.addGlobalMonitorForEvents(matching: down) { [weak self] _ in self?.pressedElsewhere = true; self?.refresh() },
            NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseUp, .rightMouseUp, .otherMouseUp]) { [weak self] _ in self?.pressedElsewhere = false; self?.refresh() },
            NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .flagsChanged, .keyDown, .scrollWheel]) { [weak self] _ in self?.refresh() },
            NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .flagsChanged]) { [weak self] event in self?.refresh(); return event },
        ].compactMap { $0 }
        // A grid or the island that opens while the pointer rests puts the launcher away.
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            if self?.models.values.contains(where: \.visible) == true { self?.refresh() }
        }
    }

    /// Asked here, not at every move of the pointer: the layouts change with the zones.
    private var wanted = Set<UUID>()

    func zonesDidChange() {
        wanted = launcherZones()
        for id in Set(panels.keys).subtracting(wanted) {   // a zone that is no longer a launcher (or is gone): its panel and model go
            panels[id]?.orderOut(nil)
            panels[id] = nil
            models[id] = nil
        }
        if !wanted.isEmpty { readEveryApp { [weak self] in self?.warm(from: 0) } }
        refresh()
    }

    private func refresh() {
        let allowed = !isCovered && !pressedElsewhere && !wanted.isEmpty && isQuiet()
            && NSEvent.modifierFlags.intersection(.deviceIndependentFlagsMask).isDisjoint(with: [.command, .option, .control, .shift, .capsLock])
        let hot = allowed ? coordinator.visibleStacks.first { $0.isEmpty && wanted.contains($0.id) && $0.rect.contains(screens.pointerAX) } : nil
        // A window under the pointer (also one that came there after the launcher showed), or a menu or the Dock in use wherever the pointer is: no launcher, or the one that showed goes.
        let shown = hot.flatMap { screens.isPointerOverWallpaper && !screens.isMenuOrDockInUse ? $0 : nil }
        for (id, model) in models where id != shown?.id && model.visible { hide(id) }
        guard let hot = shown else { return }
        let panel = panels[hot.id] ?? make(for: hot.id)
        let frame = screens.flip(hot.rect).insetBy(dx: -ZoneLauncherView.shadowRoom, dy: -ZoneLauncherView.shadowRoom)
        if panel.frame != frame { panel.setFrame(frame, display: false) }
        if models[hot.id]?.visible == false { show(panel, zone: hot.id) }
    }

    private func make(for zone: UUID) -> NSPanel {
        let model = ZoneLauncherModel()
        model.onLaunch = { [weak self] bundleID in self?.apps.launch(app: bundleID, into: zone) }
        model.onAdd = { [weak self] bundleID in self?.apps.add(app: bundleID, to: zone); self?.refill(zone) }
        model.onRemove = { [weak self] bundleID in self?.apps.remove(app: bundleID, in: zone, inZones: [zone]); self?.refill(zone) }
        model.onMove = { [weak self] bundleID, offset in self?.apps.reorder(app: bundleID, in: zone, by: offset, inZones: [zone]); self?.refill(zone) }
        model.makeGlyph = { [weak self] bundleID in self?.glyph(of: bundleID) ?? NSImage() }
        let panel = ZoneLauncherPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        // Behind every window, just above the desktop's icons: a window that reaches into the zone stays whole in front of it.
        panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary]
        panel.contentView = NSHostingView(rootView: ZoneLauncherView(model: model))
        panels[zone] = panel
        models[zone] = model
        return panel
    }

    private func show(_ panel: NSPanel, zone: UUID) {
        guard let model = models[zone] else { return }
        fill(model, zone: zone)
        panel.orderFrontRegardless()
        // On the next turn, so that the first picture is the one that is not shown yet.
        DispatchQueue.main.async { withAnimation(Self.movement) { model.visible = true } }
        reloadEveryApp { [weak self] in self?.fill(model, zone: zone) }
    }

    private func hide(_ zone: UUID) {
        guard let model = models[zone] else { return }
        withAnimation(Self.movement) { model.visible = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            if !model.visible { self?.panels[zone]?.orderOut(nil) }   // the pointer may have come back meanwhile
        }
    }

    /// The apps of the cards the zone's grid shows (one each), and every app.
    private func fill(_ model: ZoneLauncherModel, zone: UUID) {
        let skipped = ignored()
        var seen = Set<String>()
        model.placed = cards.allCards(of: zone).filter { seen.insert($0.bundleID).inserted }.map { LauncherApp(bundleID: $0.bundleID, name: $0.name) }
        let placed = Set(model.placed.map(\.bundleID))
        model.all = (everyApp ?? []).filter { !skipped.contains($0.bundleID) && !placed.contains($0.bundleID) }.map { LauncherApp(bundleID: $0.bundleID, name: $0.name) }
    }

    private func glyph(of bundleID: String) -> NSImage {
        if let kept = glyphs[bundleID] { return kept }
        let made = apps.glyph(ofApp: bundleID)
        glyphs[bundleID] = made
        return made
    }

    private func warm(from index: Int) {
        guard let list = everyApp, index < list.count else { return }
        for app in list[index..<min(index + 8, list.count)] { _ = glyph(of: app.bundleID) }
        DispatchQueue.main.async { [weak self] in self?.warm(from: index + 8) }
    }

    private func refill(_ zone: UUID) {
        if let model = models[zone] { withAnimation(.smooth(duration: 0.3)) { fill(model, zone: zone) } }
    }

    private func readEveryApp(then done: @escaping () -> Void) {
        if everyApp == nil { reloadEveryApp(then: done) }
    }

    /// Reads the folders again (an app may have been installed since), at most every half minute, off the main thread.
    private func reloadEveryApp(then done: @escaping () -> Void) {
        guard !reading, readAt.map({ Date().timeIntervalSince($0) > 30 }) ?? true else { return }
        reading = true
        readAt = Date()
        DispatchQueue.global(qos: .utility).async { [weak self, installed] in
            let list = installed.apps()
            DispatchQueue.main.async {
                self?.everyApp = list
                self?.reading = false
                done()
            }
        }
    }
}
