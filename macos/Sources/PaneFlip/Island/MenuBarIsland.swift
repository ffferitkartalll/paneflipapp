import AppKit
import PaneFlipCore
import SwiftUI

/// The island in the menu bar of every display: the zones of its layout, those beyond its edges too, with the zone of the window that has the focus lit up.
/// It is as tall as the menu bar; where there is a notch it is not shown until the pointer comes.
final class MenuBarIsland: ZonePresenting, ZoneDropTarget {
    /// One display's island.
    private final class Entry {
        let model = MenuBarIslandModel()
        let panel: NSPanel
        /// A small panel exactly over the island that takes the mouse (the picture's own panel lets it through): nothing behind the island sees the pointer.
        let shield: NSPanel
        /// The shield shrinks when the island has shrunk, not before.
        var shrinking: DispatchWorkItem?
        var zoneNames: [UUID: String] = [:]
        var zones: Set<UUID> = []
        /// How each zone is numbered: 1, 2 on the screen; -1 beyond the left edge; +1 beyond the right one.
        var numbers: [UUID: String] = [:]
        var hovered = false
        /// A drop just ended on the island: it stays closed until the pointer has left it.
        var cooling = false
        /// The zone a dragged window would be dropped on: it is lit, as a zone with the focus is.
        var dropZone: UUID?
        /// The zone of the picture a dragged window has waited on, and since when: after a second its row of cards opens.
        var dwell: (zone: UUID, since: Date)?
        /// Where the panel stands when the island is in sight.
        var rest: CGRect = .zero
        /// The layout offset the picture of the zones was built at: the frame is drawn at the offsets of the scroll minus this one.
        var builtOffset: CGFloat = 0
        /// Counts the glides told to the island: one that is overtaken does not start.
        var glides = 0
        #if DEBUG
        var mockNotch: NSPanel?
        #endif
        /// The last offset the fingers told, and whether it is being drawn already: told as often as events come, drawn once per turn of the run loop.
        var following: CGFloat?
        var dragging: CGFloat?

        init(panel: NSPanel, shield: NSPanel) {
            self.panel = panel
            self.shield = shield
        }
    }

    private let coordinator: StackCoordinator
    private let repository: LayoutRepository
    private let settings: AppSettings
    private let screens: ScreenProviding
    private let screensNow: () -> [ScreenInfo]
    private let planner: ZonePlanner
    private let viewport: StripViewport
    private let iconFont: IconFont
    private let memory: StackMemory
    private let apps: AppCatalog
    private let openApp: (String) -> Void
    private var glyphs: [String: NSImage] = [:]
    private var glyphsRevision = 0
    private var entries: [String: Entry] = [:]
    private var timer: Timer?
    private var monitor: Any?
    private var localMonitor: Any?
    /// How long the island takes to shrink back, with some room.
    private static let shrinkAfter: TimeInterval = 0.7
    private var dragging = false
    /// A card of the open row the mouse went down on: a click on it when the mouse comes up in the same place, a move of it among the cards when it is dragged.
    private var pressed: (entry: Entry, card: String, from: CGPoint, grab: CGFloat, centres: [String: CGFloat], moved: Bool)?
    private var followed: UUID?
    /// Mission Control or App Exposé is open: the islands are out of sight until it is closed.
    private var covered = false
    /// Where a dragged window would be put down among the cards of the open row: the grey card with a plus stands at `index`.
    private var placing: (zone: UUID, index: Int)?
    /// How long a dragged window waits on a zone before its row of cards opens.
    private static let dwellTime: TimeInterval = 1

    init(coordinator: StackCoordinator, repository: LayoutRepository, settings: AppSettings, screens: ScreenProviding, screensNow: @escaping () -> [ScreenInfo], planner: ZonePlanner, viewport: StripViewport, iconFont: IconFont,
         memory: StackMemory, apps: AppCatalog, openApp: @escaping (String) -> Void) {
        self.iconFont = iconFont
        self.memory = memory
        self.apps = apps
        self.openApp = openApp
        self.screensNow = screensNow
        self.planner = planner
        self.viewport = viewport
        self.coordinator = coordinator
        self.repository = repository
        self.settings = settings
        self.screens = screens
    }

    func start() {
        // A cheap test of where the pointer is, per move: in other apps' windows (global), and over the island's own shield and PaneFlip's windows (local).
        monitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] _ in self?.hover(at: NSEvent.mouseLocation) }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .mouseMoved) { [weak self] event in
            self?.hover(at: NSEvent.mouseLocation)
            return event
        }
        timer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { [weak self] _ in
            guard let self else { return }
            // The lit zone follows the focus also while windows move (a layout scrolls to a zone beyond the edge): it costs next to nothing, and the zone the
            // focus goes to must not wait for the scroll to be over.
            if followed != coordinator.focusedZoneID { followFocus() }
            let covering = screens.isMissionControlActive
            if covering != covered { cover(covering) }
            guard !coordinator.isMoving else { return }   // the row moves with the fingers; the next tick catches up
            for entry in entries.values {
                refreshWindows(of: entry)   // a window that came, went or came to the front while the row is open
                refreshCrowding(of: entry)
            }
            warmGlyph()
        }
    }

    // MARK: ZonePresenting

    func zonesDidChange() {
        // Not while the layout scrolls: the picture holds the whole strip and does not change, the frame glides over it, and this asks the Dock about the screens.
        // The scroll ends with a change of its own.
        guard !coordinator.isScrolling else { return }
        guard settings.values.placementEnabled else { return removeAll() }
        let current = screensNow()
        for (id, entry) in entries where !current.contains(where: { $0.displayID == id }) {
            entry.panel.orderOut(nil)
            entry.shield.orderOut(nil)
            entries[id] = nil
        }
        for screen in current {
            // A full-screen app has the display: no menu bar, no island.
            guard screen.desktopNumber != nil, let layout = repository.activeLayout(for: screen.key) else { remove(screen.displayID); continue }
            let known = entries[screen.displayID]
            let entry = known ?? makeEntry(for: screen)
            update(entry, screen: screen, layout: layout, among: current)
            if known == nil && !covered { slideIn(entry) }
        }
        followFocus()
    }

    private func cover(_ covering: Bool) {
        covered = covering
        for entry in entries.values {
            if covering {
                if entry.hovered { setOpen(false, for: entry) }
                entry.shield.orderOut(nil)
                slideAway(entry) { [weak self, weak entry] in if self?.covered == true { entry?.panel.orderOut(nil) } }
            } else {
                entry.shield.orderFrontRegardless()
                slideIn(entry)
            }
        }
    }

    private static let slideTime: TimeInterval = 0.25

    /// The island goes up out of the screen, fading, and `done` runs when it has gone.
    private func slideAway(_ entry: Entry, done: @escaping () -> Void) {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = Self.slideTime
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            entry.panel.animator().setFrame(entry.rest.offsetBy(dx: 0, dy: entry.model.barHeight), display: true)
            entry.panel.animator().alphaValue = 0
        }, completionHandler: done)
    }

    /// The island comes down from above the screen to where it stands, fading in.
    private func slideIn(_ entry: Entry) {
        entry.panel.setFrame(entry.rest.offsetBy(dx: 0, dy: entry.model.barHeight), display: true)
        entry.panel.alphaValue = 0
        entry.panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = Self.slideTime
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            entry.panel.animator().setFrame(entry.rest, display: true)
            entry.panel.animator().alphaValue = 1
        }
    }

    private func update(_ entry: Entry, screen: ScreenInfo, layout: NamedLayout, among all: [ScreenInfo]) {
        // The whole height of the menu bar there: what the screen leaves above its usable area (nothing when the bar hides).
        let native = NSScreen.screens.first { $0.frame == screen.cocoaFrame }
        let bar = ceil(max(native.map { $0.frame.maxY - $0.visibleFrame.maxY } ?? 0, screen.notchHeight, screens.menuBarThickness))
        let margin = MenuBarIslandView.margin
        let height = bar - 2 * margin
        let model = entry.model
        entry.zoneNames = layout.zoneNames
        entry.zones = Set(layout.zoneIDs)
        defer { model.cellTexts = entry.zones.subtracting(layout.floatingZone.map { [$0.id] } ?? []).reduce(into: [:]) { $0[$1] = entry.zoneNames[$1] ?? entry.numbers[$1] } }
        entry.numbers = Dictionary(uniqueKeysWithValues: layout.zoneIDs.map { ($0, ZoneLabel.text(of: $0, in: layout.strip)) })
        // How far the layout can be scrolled either way: the picture holds the whole strip, whatever the scroll.
        var reach: ClosedRange<CGFloat> = 0 ... 0
        entry.builtOffset = 0
        if let (geometry, _) = planner.strip(of: screen, among: all) {
            let offset = geometry.clamped(viewport.offset(for: screen.key))
            reach = (geometry.range.lowerBound - offset) ... (geometry.range.upperBound - offset)
            entry.builtOffset = offset
        }
        // The frame is the area the zones lie in (not under the menu bar or the Dock), so that the zones fill it to its edges.
        model.glyph = ZoneGlyph(zones: layout.zoneIDs.compactMap { id in coordinator.stacks[id].map { (id, $0.rect) } },
                                screen: screen.axVisible, screenSize: CGSize(width: height * screen.axVisible.width / max(screen.axVisible.height, 1), height: height),
                                grow: CGFloat(layout.gap ?? settings.values.gap) / 2, screenShifts: reach)
        withTransaction(Transaction(animation: nil)) { model.outlineShift = 0 }   // the glyph stands where the glide ended
        model.barHeight = bar
        model.notchWidth = screen.notchWidth
        model.scale = native?.backingScaleFactor ?? 2
        // The open island is as wide as its picture and the room beside it, and must fit the display.
        model.crowded = isCrowded(entry)
        model.openZoom = model.fitZoom(toDisplayWidth: screen.cocoaFrame.width)
        let width = screen.cocoaFrame.width
        // Tall enough for the island at its largest, with a row of cards under its picture.
        let tall = ceil(model.tallestOpenHeight)
        let frame = CGRect(x: screen.cocoaFrame.midX - width / 2, y: screen.cocoaFrame.maxY - tall, width: width, height: tall)
        entry.rest = frame
        if !covered && entry.panel.frame != frame { entry.panel.setFrame(frame, display: true) }
        if !covered { entry.panel.orderFrontRegardless() }
        refreshWindows(of: entry)
        entry.shrinking?.cancel()
        entry.shield.setFrame(islandFrame(of: entry, open: entry.hovered), display: false)
        if !covered { entry.shield.orderFrontRegardless() }
        #if DEBUG
        showMockNotch(of: entry, on: screen, bar: bar)
        #endif
    }

    #if DEBUG
    /// With a fake notch (see `CGSScreenProvider.fakeNotch`) a black notch is drawn too, to see how the island sits around it.
    private func showMockNotch(of entry: Entry, on screen: ScreenInfo, bar: CGFloat) {
        guard CGSScreenProvider.fakeNotch != nil, screen.notchWidth > 0, NSScreen.screens.first?.safeAreaInsets.top == 0 else { return }
        let frame = CGRect(x: screen.cocoaFrame.midX - screen.notchWidth / 2, y: screen.cocoaFrame.maxY - screen.notchHeight, width: screen.notchWidth, height: screen.notchHeight)
        if entry.mockNotch == nil {
            let p = NSPanel(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            p.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)
            p.isOpaque = false
            p.backgroundColor = .clear
            p.hasShadow = false
            p.ignoresMouseEvents = true
            p.collectionBehavior = [.canJoinAllSpaces, .stationary]
            p.contentView = NSHostingView(rootView: UnevenRoundedRectangle(bottomLeadingRadius: 10, bottomTrailingRadius: 10).fill(.black).ignoresSafeArea())
            entry.mockNotch = p
        }
        entry.mockNotch?.setFrame(frame, display: true)
        entry.mockNotch?.orderFrontRegardless()
    }
    #endif

    // MARK: Scrolling

    /// The layout of a screen glides to the layout offset `to` (in step with the pictures on the screen, same curve and time): the frame of the screen
    /// slides along the strip drawn small. One animation, started here; nothing is told per frame. `from`: where it starts (nil: where the frame is).
    /// Offsets are the layout's own, not relative to where a scroll began: the island knows the offset its picture was built at.
    func glide(on screen: ScreenInfo, from: CGFloat?, to: CGFloat) {
        guard let entry = entries[screen.displayID], screen.axVisible.width > 0 else { return }
        let model = entry.model
        let scale = model.glyph.screen.width / screen.axVisible.width
        entry.glides += 1
        let glide = entry.glides
        if let from { withTransaction(Transaction(animation: nil)) { model.outlineShift = (from - entry.builtOffset) * scale } }
        DispatchQueue.main.async {
            guard entry.glides == glide else { return }
            withAnimation(.timingCurve(0.215, 0.61, 0.355, 1, duration: 0.3)) { model.outlineShift = (to - entry.builtOffset) * scale }
        }
    }

    /// The fingers lead the layout: the frame follows them, as the small picture of the scroll on the screen does.
    func follow(on screen: ScreenInfo, offset: CGFloat) {
        guard let entry = entries[screen.displayID], screen.axVisible.width > 0 else { return }
        entry.glides += 1   // a glide that is on its way gives way to the fingers
        let queued = entry.following != nil
        entry.following = offset
        guard !queued else { return }
        // Not inside the handling of the finger event: the events come first.
        DispatchQueue.main.async {
            guard let offset = entry.following else { return }
            entry.following = nil
            withTransaction(Transaction(animation: nil)) { entry.model.outlineShift = (offset - entry.builtOffset) * entry.model.glyph.screen.width / screen.axVisible.width }
        }
    }

    // MARK: What scrolls over the island

    /// What the wheel and two fingers scroll with the pointer here, if it is on an island that is open: over the picture, and the room round it, the layout of
    /// the screen; over the cards of the zone chosen in the picture, the windows of that zone (when it stands on the screen and has more than one window).
    func scrollTarget(at point: CGPoint) -> ScrollSwitchTarget? {
        for entry in entries.values where entry.hovered {
            let frame = islandFrame(of: entry, open: true), model = entry.model
            guard frame.contains(point) else { continue }
            guard let zone = model.windowsZone, frame.maxY - point.y > model.barHeight + model.glyph.size.height * model.openZoom + model.windowsGap / 2 else { return .strip }
            guard let stack = coordinator.stacks[zone], stack.tabs.count > 1, !stack.isParked, !stack.isFloating else { return nil }
            return .zoneWindows(zone)
        }
        return nil
    }

    /// The windows of the zones changed (one came to the front): the rows of cards show it at once.
    func windowsDidChange() {
        for entry in entries.values { refreshWindows(of: entry) }
    }

    /// The focus was moved by a shortcut: the lit zone follows at once, not at the next look.
    func focusDidMove() { followFocus() }

    /// The fingers lead the windows of a zone (`fraction` of its width; 0: they let go, and the windows settle with the spring of the pictures on the screen).
    func windowsScrubbed(zone: UUID, by fraction: CGFloat) {
        for entry in entries.values where entry.model.windowsZone == zone {
            if fraction == 0 {
                entry.dragging = nil
                withAnimation(.interpolatingSpring(mass: 1, stiffness: SlideSpring.stiffness, damping: SlideSpring.damping)) { entry.model.windowsDrag = 0 }
            } else {
                // Not inside the handling of the finger event, and once for all the events that came meanwhile.
                let queued = entry.dragging != nil
                entry.dragging = fraction
                guard !queued else { continue }
                DispatchQueue.main.async {
                    guard let fraction = entry.dragging else { return }
                    entry.dragging = nil
                    withTransaction(Transaction(animation: nil)) { entry.model.windowsDrag = fraction }
                }
            }
        }
    }

    // MARK: Hover

    private func hover(at point: CGPoint) {
        for entry in entries.values {
            let model = entry.model, bar = entry.panel.frame
            let m = MenuBarIslandView.margin
            let hit: Bool
            if entry.hovered {
                // The block below the bar, and the bar's row above it, which the pointer crosses to get there.
                let size = model.openSize
                hit = point.y >= bar.maxY - size.height && point.y <= bar.maxY && abs(point.x - bar.midX) <= size.width / 2
            } else {
                // The island itself; with a notch, the notch and the height of the menu bar beside it (the island is not shown at rest there).
                let half = model.notchWidth > 0 ? model.notchWidth / 2 + model.barHeight : model.glyph.size.width / 2 + m
                // Dragging a window, the pointer need not hit the island exactly: three times the height of the menu bar around it (left, right, below).
                let reach = dragging ? 3 * model.barHeight : 0
                hit = point.y >= bar.maxY - model.barHeight - reach && point.y <= bar.maxY && abs(point.x - bar.midX) <= half + reach
            }
            if entry.cooling { if hit { continue }; entry.cooling = false }
            let overRow = dragging && hit && entry.hovered && rowHit(at: point, in: entry).onRow
            let drop = dragging && hit && entry.hovered ? (overRow ? entry.model.windowsZone : cell(at: point, in: entry)) : nil
            if drop != entry.dropZone { entry.dropZone = drop; entry.model.select(drop ?? focused(in: entry)) }
            if dragging { prepareDrop(on: overRow ? nil : drop, overRow: overRow, at: point, in: entry) }
            guard hit != entry.hovered else { continue }
            setOpen(hit, for: entry)
        }
    }

    /// A dragged window is over the island: over the row of cards it shows where it would be put down; waiting on a zone of the picture opens that zone's row.
    private func prepareDrop(on zone: UUID?, overRow: Bool, at point: CGPoint, in entry: Entry) {
        let model = entry.model
        if overRow, let open = model.windowsZone {
            // After the cards whose middle, as the row lies now, is left of the pointer (the grey card itself does not count). A card that is already
            // counted stays counted a little past its middle, so that a pointer resting on a card does not flip the grey card from one side to the other.
            let x = point.x - islandFrame(of: entry, open: true).midX, held = placing?.zone == open ? placing?.index : nil
            let cards = model.windows.indices.filter { !model.windows[$0].isPlaceholder }
            let left = cards.enumerated().filter { n, card in x > model.cardCentre(of: card) + (held.map { n < $0 } == true ? -10 : 10) }.count
            setPlacing(left, in: open, entry)
            entry.dwell = nil
            return
        }
        setPlacing(nil, in: nil, entry)
        guard let zone else { return entry.dwell = nil }
        guard let dwell = entry.dwell, dwell.zone == zone else { return entry.dwell = (zone, Date()) }
        guard model.windowsZone != zone, Date().timeIntervalSince(dwell.since) >= Self.dwellTime else { return }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.78)) {
            entry.dragging = nil
            model.windowsDrag = 0
            model.windows = windows(of: zone)
            model.windowsZone = zone
        }
        placeShield(of: entry)
    }

    private func setPlacing(_ index: Int?, in zone: UUID?, _ entry: Entry) {
        // Another display's island is not this one's business.
        if index == nil, let current = placing?.zone, !entry.zones.contains(current) { return }
        guard placing?.zone != zone || placing?.index != index else { return }
        placing = zone.flatMap { zone in index.map { (zone, $0) } }
        guard let shown = entry.model.windowsZone else { return }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { entry.model.windows = windows(of: shown) }
    }

    private func setOpen(_ open: Bool, for entry: Entry) {
        entry.hovered = open
        if !open { withAnimation(.easeOut(duration: 0.08)) { entry.model.contentOpacity = 0 } }
        // The pointer comes onto the island while a zone has the focus: its windows show as if its zone had been clicked, and the island grows to hold them.
        let zone = open && !dragging ? focused(in: entry).flatMap { coordinator.stacks[$0]?.isEmpty == false ? $0 : nil } : nil
        withAnimation(.spring(response: 0.4, dampingFraction: 0.78)) {
            entry.model.expanded = open
            if open { entry.model.contentOpacity = 1 }
            entry.model.zoom = open ? entry.model.openZoom : 1
            if !open { entry.model.windowsZone = nil; entry.dragging = nil; entry.model.windowsDrag = 0 }   // the row goes with the island; a late end of a swipe cannot leave it offset
            if let zone {
                entry.dragging = nil
                entry.model.windowsDrag = 0
                entry.model.windows = windows(of: zone)
                entry.model.windowsZone = zone
            }
        }
        placeShield(of: entry)
    }

    /// Where the island stands, or will stand once it has grown, at the top of its display (screen coordinates): what the shield covers.
    private func islandFrame(of entry: Entry, open: Bool) -> CGRect {
        let model = entry.model, top = entry.panel.frame
        let size = open ? model.openSize : CGSize(width: model.notchWidth > 0 ? model.notchWidth : model.glyph.size.width + 2 * MenuBarIslandView.margin, height: model.barHeight)
        return CGRect(x: top.midX - size.width / 2, y: top.maxY - size.height, width: size.width, height: size.height)
    }

    /// The shield grows with the island at once, so that the island never has the mouse go through it, and shrinks once the island has shrunk.
    private func placeShield(of entry: Entry) {
        entry.shrinking?.cancel()
        entry.shrinking = nil
        let target = islandFrame(of: entry, open: entry.hovered), current = entry.shield.frame
        let covering = current.isEmpty ? target : current.union(target)
        if covering != current { entry.shield.setFrame(covering, display: false) }
        guard covering != target else { return }
        let work = DispatchWorkItem { [weak self, weak entry] in
            guard let self, let entry else { return }
            entry.shield.setFrame(islandFrame(of: entry, open: entry.hovered), display: false)
        }
        entry.shrinking = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.shrinkAfter, execute: work)
    }

    // MARK: The windows of a zone

    /// The mouse went down on the shield: on a card of the open row it waits to see whether this is a click or a drag; on a zone in the picture it is a click.
    private func press(at point: CGPoint) {
        pressed = nil
        for entry in entries.values where entry.hovered && islandFrame(of: entry, open: true).contains(point) {
            let row = rowHit(at: point, in: entry)
            guard row.onRow else { continue }
            if let index = row.card {
                let model = entry.model
                pressed = (entry, model.windows[index].id, point, point.x - islandFrame(of: entry, open: true).midX - model.cardCentre(of: index),
                           Dictionary(uniqueKeysWithValues: model.windows.indices.map { (model.windows[$0].id, model.cardCentre(of: $0)) }), false)
            }
            return
        }
        click(at: point)
    }

    private func drag(to point: CGPoint) {
        guard var current = pressed else { return }
        if !current.moved && hypot(point.x - current.from.x, point.y - current.from.y) < 4 { return }
        let model = current.entry.model, middle = islandFrame(of: current.entry, open: true).midX
        // The card is where the mouse is, as it was held.
        let centre = point.x - middle - current.grab
        if !current.moved {
            // The card is held up and the hand takes it, from where it lay.
            withTransaction(Transaction(animation: nil)) {
                model.carriedX = current.from.x - middle - current.grab
                model.carriedCard = current.card
                if model.windows.first(where: { $0.id == current.card })?.isActive == true { model.pinnedFront = model.windows.firstIndex { $0.isActive } }
            }
            (current.entry.shield.contentView as? IslandShieldView)?.cursor = .closedHand
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { model.liftedCard = current.card }
            current.moved = true
            pressed = current
        }
        withTransaction(Transaction(animation: nil)) { model.carriedX = centre }
        // Where the card goes among the others: after the cards whose middle, as the row lay when the mouse went down, is left of the card's middle. The row
        // moves as the cards change places, so what it lay like then is what is measured.
        guard let zone = model.windowsZone, let from = model.windows.firstIndex(where: { $0.id == current.card }) else { return }
        let to = model.windows.filter { $0.id != current.card }.filter { (current.centres[$0.id] ?? 0) < centre }.count
        guard to != from, let source = slot(of: model.windows[from], in: zone), let target = slot(of: model.windows[to], in: zone) else { return }
        coordinator.moveSlot(source, toPlaceOf: target, inZone: zone)
        withAnimation(.spring(response: 0.4, dampingFraction: 0.78)) { model.windows = windows(of: zone) }
    }

    private func release(at point: CGPoint) {
        guard let current = pressed else { return }
        pressed = nil
        let model = current.entry.model
        guard current.moved else {
            if let zone = model.windowsZone, let card = model.windows.first(where: { $0.id == current.card }) { choose(card, in: zone) }
            return
        }
        // The card goes to its place and is put down.
        (current.entry.shield.contentView as? IslandShieldView)?.cursor = nil
        withAnimation(.spring(response: 0.4, dampingFraction: 0.78)) {
            model.pinnedFront = nil   // the front card, if it was carried, comes back to the middle with the row
            if let index = model.carried { model.carriedX = model.cardCentre(of: index) }
            model.liftedCard = nil
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if model.liftedCard == nil, model.carriedCard == current.card { model.carriedCard = nil }   // in its place: it is laid out with the others again
        }
    }

    /// The slot of the memory that a card stands for: its window's, or the first of the app that is not open.
    private func slot(of card: IslandWindow, in zone: UUID) -> Int? {
        memory.slots(inZones: [zone]).first { card.windowID != nil ? $0.windowID == card.windowID : $0.bundleID == card.bundleID }?.index
    }

    /// A click on the shield: on a zone in the picture of the open island, a row of cards, one for each window of that zone, opens under the picture and the island
    /// grows to hold it; on the same zone again, the row closes and the island shrinks back.
    private func click(at point: CGPoint) {
        for entry in entries.values where entry.hovered && islandFrame(of: entry, open: true).contains(point) {
            guard let zone = cell(at: point, in: entry) else { continue }
            coordinator.focus(zone: zone)
            followFocus()   // the highlight goes to the zone at once
            withAnimation(.spring(response: 0.4, dampingFraction: 0.78)) {
                if entry.model.windowsZone == zone {
                    entry.model.windowsZone = nil
                } else {
                    entry.dragging = nil
                    entry.model.windowsDrag = 0
                    entry.model.windows = windows(of: zone)
                    entry.model.windowsZone = zone
                }
            }
            placeShield(of: entry)
        }
    }

    /// Whether the point is on the open row of cards, and the card under it, if any.
    private func rowHit(at point: CGPoint, in entry: Entry) -> (onRow: Bool, card: Int?) {
        let model = entry.model, frame = islandFrame(of: entry, open: true), size = model.windowsFrame
        guard model.windowsZone != nil, size.width > 0 else { return (false, nil) }
        let top = model.barHeight + model.glyph.size.height * model.openZoom + model.windowsGap, fromTop = frame.maxY - point.y
        guard fromTop >= top, fromTop <= top + size.height, abs(point.x - frame.midX) <= model.cardsFit / 2 else { return (false, nil) }
        return (true, model.card(atX: point.x - frame.midX))
    }

    /// A click on a card of the open row: that window comes to the front of its zone and the focus goes with it; an app that is not open is opened.
    private func choose(_ card: IslandWindow, in zone: UUID) {
        guard let stack = coordinator.stacks[zone], !stack.isParked, !stack.isFloating else { return }
        if let id = card.windowID {
            if card.isActive { coordinator.focus(zone: zone) } else { coordinator.slideSelect(id, in: stack) }
            followFocus()
        } else {
            openApp(card.bundleID)
        }
    }

    /// The windows of the open row: as they are now (one that came, went or came to the front is shown), or, if the zone is gone, no row.
    private func refreshWindows(of entry: Entry) {
        guard let zone = entry.model.windowsZone else { return }
        guard entry.zones.contains(zone) else {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.78)) { entry.model.windowsZone = nil }
            return placeShield(of: entry)
        }
        let now = windows(of: zone)
        // Nothing changed (nearly every look): no animation, no shield to place.
        guard now != entry.model.windows else { return }
        // Another window in front only moves the row: with the spring of the pictures on the screen. Windows that came or went grow or shrink the island.
        let moves = now.map(\.id) == entry.model.windows.map(\.id)
        let spring: Animation = moves ? .interpolatingSpring(mass: 1, stiffness: SlideSpring.stiffness, damping: SlideSpring.damping) : .spring(response: 0.4, dampingFraction: 0.78)
        withAnimation(spring) { entry.model.windows = now }
        placeShield(of: entry)
    }

    /// A zone on the screen has several cards: the island is laid out for more room (`roomWidth`).
    private func isCrowded(_ entry: Entry) -> Bool {
        entry.model.glyph.cells.contains { $0.isOnScreen && cardCount(of: $0.id) > 1 }
    }

    private func refreshCrowding(of entry: Entry) {
        let crowded = isCrowded(entry)
        guard crowded != entry.model.crowded else { return }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.78)) {
            entry.model.crowded = crowded
            entry.model.openZoom = entry.model.fitZoom(toDisplayWidth: entry.panel.frame.width)
        }
        placeShield(of: entry)
    }

    /// How many cards `windows(of:)` makes for a zone, counted without the pictures: its windows and the apps of the zone that are not open.
    private func cardCount(of zone: UUID) -> Int {
        guard let stack = coordinator.stacks[zone] else { return 0 }
        let open = Set(stack.tabs.map(\.bundleID))
        let closed = Set(memory.slots(inZones: [zone]).map(\.bundleID)).subtracting(open)
        return stack.tabs.count + closed.count
    }

    /// While the island rests, the picture of one more app is made at each look, so that the first click on a zone does not wait for it (the font that
    /// holds the pictures is made again for each new one).
    private func warmGlyph() {
        guard !entries.values.contains(where: \.hovered) else { return }
        for stack in coordinator.stacks.values {
            for tab in stack.tabs where glyphs[tab.bundleID.isEmpty ? tab.appName : tab.bundleID] == nil || glyphsRevision != iconFont.revision {
                _ = glyph(of: tab)
                return
            }
        }
    }

    /// The picture of an app is made once (the font gives a new image every time, and the rows are refreshed several times a second); made again when a brand glyph arrives.
    private func glyph(of tab: ZoneStack.Tab) -> NSImage {
        glyph(bundleID: tab.bundleID, appName: tab.appName, icon: tab.icon)
    }

    private func glyph(bundleID: String, appName: String, icon: NSImage?) -> NSImage {
        if glyphsRevision != iconFont.revision { glyphs = [:]; glyphsRevision = iconFont.revision }
        let key = bundleID.isEmpty ? appName : bundleID
        if let known = glyphs[key] { return known }
        let made = iconFont.image(bundleID: bundleID, appName: appName, icon: icon ?? NSWorkspace.shared.icon(for: .applicationBundle), size: 32)
        glyphs[key] = made
        return made
    }

    /// The cards of a zone in the order of the zone: its windows, and the apps of the zone that are not open, each in its place.
    private func windows(of zone: UUID) -> [IslandWindow] {
        guard let stack = coordinator.stacks[zone] else { return [] }
        let tabs = Dictionary(stack.tabs.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let openApps = Set(stack.tabs.map(\.bundleID))
        let slots = memory.slots(inZones: [zone])
        let running = Set(apps.regularApps(withBundleIDs: Set(slots.map(\.bundleID))).map(\.bundleID))
        var cards: [IslandWindow] = [], shown = Set<CGWindowID>(), closed = Set<String>()
        func card(_ tab: ZoneStack.Tab) -> IslandWindow {
            IslandWindow(windowID: tab.id, bundleID: tab.bundleID, name: tab.displayName.isEmpty ? tab.appName : tab.displayName, glyph: glyph(of: tab),
                         glyphRevision: iconFont.revision, absence: nil, isActive: tab.id == stack.activeID)
        }
        for slot in slots {
            if let id = slot.windowID, let tab = tabs[id] {
                cards.append(card(tab))
                shown.insert(id)
            } else if !openApps.contains(slot.bundleID), closed.insert(slot.bundleID).inserted {
                let name = apps.name(bundleID: slot.bundleID) ?? slot.bundleID
                // An app that is not running is closed, whatever became of its last window.
                let absence = running.contains(slot.bundleID) ? coordinator.absences[slot.bundleID] ?? .closed : .closed
                cards.append(IslandWindow(windowID: nil, bundleID: slot.bundleID, name: name, glyph: glyph(bundleID: slot.bundleID, appName: name, icon: apps.icon(bundleID: slot.bundleID)),
                                          glyphRevision: iconFont.revision, absence: absence, isActive: false))
            }
        }
        cards += stack.tabs.filter { !shown.contains($0.id) }.map(card)   // a window the memory does not know yet stands last
        if let placing, placing.zone == zone { cards.insert(.placeholder, at: min(placing.index, cards.count)) }
        return cards
    }

    private func focused(in entry: Entry) -> UUID? { coordinator.focusedZoneID.flatMap { entry.zones.contains($0) ? $0 : nil } }

    /// The zone of the picture under the point, as the open island lays it out: centred, the picture the height of the menu bar from the left, top and bottom.
    private func cell(at point: CGPoint, in entry: Entry) -> UUID? {
        let model = entry.model, bar = model.barHeight, frame = entry.panel.frame
        let x = (point.x - (frame.midX - model.glyph.size.width * model.openZoom / 2)) / model.openZoom, y = (frame.maxY - point.y - bar) / model.openZoom
        guard entry.hovered else { return nil }
        return model.glyph.cells.last { coordinator.stacks[$0.id] != nil && $0.rect.contains(CGPoint(x: x, y: y)) }?.id
    }

    // MARK: ZoneDropTarget

    func dragMoved(to point: CGPoint) {
        dragging = true
        hover(at: point)
    }

    func isOver(_ point: CGPoint) -> Bool {
        hover(at: point)
        return entries.values.contains { $0.hovered }
    }

    func drop(_ window: WindowRef, at point: CGPoint) {
        hover(at: point)
        let index = placing?.index
        let zone = placing?.zone ?? entries.values.lazy.compactMap { self.cell(at: point, in: $0) }.first
        placing = nil
        guard let zone else { return }
        // The cards beside the place, before the window comes: its own card, if it was in this zone, is not a neighbour.
        let others = windows(of: zone).enumerated().filter { $0.element.windowID != window.id }
        let next = index.flatMap { i in others.first { $0.offset >= i }?.element }, last = others.last?.element
        coordinator.snap(window, into: zone)
        guard index != nil, let own = memory.index(ofWindow: window.id) else { return }
        if let next, let beside = slot(of: next, in: zone) {
            coordinator.moveSlot(own, toPlaceOf: StackMemory.place(of: own, beside: beside, after: false), inZone: zone)
        } else if let last, let beside = slot(of: last, in: zone) {
            coordinator.moveSlot(own, toPlaceOf: StackMemory.place(of: own, beside: beside, after: true), inZone: zone)
        }
    }

    func dragEnded() {
        dragging = false
        placing = nil
        for entry in entries.values {
            entry.dwell = nil
            if entry.dropZone != nil { entry.dropZone = nil; entry.model.select(focused(in: entry)) }
            if entry.hovered { entry.cooling = true; setOpen(false, for: entry) }   // the drop is done: the island closes, and opens again for a new visit
        }
    }

    // MARK: Focus

    private func followFocus() {
        let id = coordinator.focusedZoneID
        followed = id
        for entry in entries.values where entry.dropZone == nil { entry.model.select(focused(in: entry)) }
    }

    // MARK: Panels

    /// One panel across the top of the display, clear but for the island; the island grows inside it. The mouse goes through it; the shield, a second panel, takes it.
    private func makeEntry(for screen: ScreenInfo) -> Entry {
        let p = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        p.level = .statusBar
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = false
        p.ignoresMouseEvents = true
        p.collectionBehavior = [.canJoinAllSpaces, .stationary]
        let shield = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        shield.level = .statusBar
        shield.isOpaque = false
        shield.backgroundColor = .clear
        shield.hasShadow = false
        shield.acceptsMouseMovedEvents = true
        shield.collectionBehavior = [.canJoinAllSpaces, .stationary]
        // Not quite clear: the window server lets the mouse through the pixels of a window that are fully clear. A hundredth of black cannot be seen.
        let cover = IslandShieldView(frame: .zero)
        cover.onPress = { [weak self] point in self?.press(at: point) }
        cover.onDrag = { [weak self] point in self?.drag(to: point) }
        cover.onRelease = { [weak self] point in self?.release(at: point) }
        cover.wantsLayer = true
        cover.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.01).cgColor
        shield.contentView = cover
        let entry = Entry(panel: p, shield: shield)
        let hosting = NSHostingView(rootView: MenuBarIslandView(model: entry.model))
        // The panel is sized here, never by its content: the content changes size with every step of the animation, and a window that asks again for
        // its size after each one never settles (the layout pass runs over and over).
        hosting.sizingOptions = []
        hosting.safeAreaRegions = []
        // Behind a plain view, so that the window's own layout does not run through the hosting view (it would ask for its size again after each pass).
        let container = NSView(frame: .zero)
        hosting.frame = container.bounds
        hosting.autoresizingMask = [.width, .height]
        container.addSubview(hosting)
        p.contentView = container
        entries[screen.displayID] = entry
        return entry
    }

    private func remove(_ id: String) {
        guard let entry = entries[id] else { return }
        entry.shrinking?.cancel()
        entry.shield.orderOut(nil)
        entries[id] = nil
        slideAway(entry) { entry.panel.orderOut(nil) }
    }

    private func removeAll() { Array(entries.keys).forEach(remove) }
}
