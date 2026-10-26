import AppKit
import PaneFlipCore
import SwiftUI

/// The island in the menu bar of every display: the zones of its layout, those beyond its edges too, with the zone of the window that has the focus lit up,
/// and that zone's name. It hangs from the notch where there is one and is as tall as the menu bar.
final class MenuBarIsland: ZonePresenting {
    /// One display's island.
    private final class Entry {
        let model = MenuBarIslandModel()
        let panel: NSPanel
        var zoneNames: [UUID: String] = [:]
        var zones: Set<UUID> = []
        /// The layout offset the picture of the zones was built at: the frame is drawn at the offsets of the scroll minus this one.
        var builtOffset: CGFloat = 0
        /// Counts the glides told to the island: one that is overtaken does not start.
        var glides = 0
        #if DEBUG
        var mockNotch: NSPanel?
        #endif
        /// The last offset the fingers told, and whether it is being drawn already: told as often as events come, drawn once per turn of the run loop.
        var following: CGFloat?

        init(panel: NSPanel) { self.panel = panel }
    }

    private let coordinator: StackCoordinator
    private let repository: LayoutRepository
    private let settings: AppSettings
    private let screens: ScreenProviding
    private let screensNow: () -> [ScreenInfo]
    private let planner: ZonePlanner
    private let viewport: StripViewport
    private var entries: [String: Entry] = [:]
    private var timer: Timer?
    private var followed: UUID?

    init(coordinator: StackCoordinator, repository: LayoutRepository, settings: AppSettings, screens: ScreenProviding, screensNow: @escaping () -> [ScreenInfo], planner: ZonePlanner, viewport: StripViewport) {
        self.screensNow = screensNow
        self.planner = planner
        self.viewport = viewport
        self.coordinator = coordinator
        self.repository = repository
        self.settings = settings
        self.screens = screens
    }

    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { [weak self] _ in
            guard let self, followed != coordinator.focusedZoneID else { return }
            followFocus()
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
            entries[id] = nil
        }
        for screen in current {
            guard let layout = repository.activeLayout(for: screen.key) else { remove(screen.displayID); continue }
            update(entries[screen.displayID] ?? makeEntry(for: screen), screen: screen, layout: layout, among: current)
        }
        followFocus()
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
        let width = min(1000, screen.cocoaFrame.width)
        let frame = CGRect(x: screen.cocoaFrame.midX - width / 2, y: screen.cocoaFrame.maxY - bar, width: width, height: bar)
        if entry.panel.frame != frame { entry.panel.setFrame(frame, display: true) }
        entry.panel.orderFrontRegardless()
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

    // MARK: Focus

    private func followFocus() {
        let id = coordinator.focusedZoneID
        followed = id
        for entry in entries.values {
            let here = id.flatMap { entry.zones.contains($0) ? $0 : nil }
            entry.model.select(here)
            let stack = here.flatMap { coordinator.stacks[$0] }
            let name = here.flatMap { entry.zoneNames[$0] }.map { String(localized: "Zone: \($0)") } ?? (stack.map { $0.isFloating ? String(localized: "Floating zone") : String(localized: "Zone: \(String($0.number))") } ?? "")
            entry.model.label = name
            entry.model.labelWidth = name.isEmpty ? 0 : ceil((name as NSString).size(withAttributes: [.font: NSFont.menuBarFont(ofSize: 0)]).width)
        }
    }

    // MARK: Panels

    /// One panel across the top of the display, clear but for the island; the island grows inside it.
    private func makeEntry(for screen: ScreenInfo) -> Entry {
        let p = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        p.level = .statusBar
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = false
        p.ignoresMouseEvents = true
        p.collectionBehavior = [.canJoinAllSpaces, .stationary]
        let entry = Entry(panel: p)
        p.contentView = NSHostingView(rootView: MenuBarIslandView(model: entry.model))
        entries[screen.displayID] = entry
        return entry
    }

    private func remove(_ id: String) {
        entries[id]?.panel.orderOut(nil)
        entries[id] = nil
    }

    private func removeAll() { Array(entries.keys).forEach(remove) }
}
