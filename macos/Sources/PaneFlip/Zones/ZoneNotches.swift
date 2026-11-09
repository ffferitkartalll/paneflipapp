import AppKit
import PaneFlipCore
import SwiftUI

/// Shows a notch at the top inner edge of every zone in view that holds a window (see `ZoneNotchView`). Each notch is a small panel of its own (the window under it is
/// found by its title bar everywhere else), standing just above the window in front of its zone: every window above that one covers the notch too. The notch the pointer is on is lit, and a press on it opens the row of the zone's windows, as a switch does, without switching. While the
/// zone's windows are switched, its notch grows into a row of its open windows, above the pictures that slide, until a moment after the switch. The wheel and two
/// fingers on a notch switch its zone's windows, as on the open island's row of cards (`scrollTarget`). While the layout scrolls to the screens beyond the edge there are none.
final class ZoneNotches: ZonePresenting {
    private let coordinator: StackCoordinator
    private let settings: AppSettings
    private let screens: ScreenProviding
    private let screensNow: () -> [ScreenInfo]
    /// The windows of a zone as the island's cards have them, and how wide the open island writes the title of a card on the display of a zone.
    private let cards: (UUID) -> [IslandWindow]
    private let titleWidth: (UUID) -> CGFloat?
    private var panels: [UUID: NSPanel] = [:]
    private var models: [UUID: ZoneNotchModel] = [:]
    private var timer: Timer?
    private var mouseMonitor: Any?
    private var hoverMonitors: [Any] = []
    /// The zone whose notch is grown to show a switch of its windows.
    private var grown: UUID?
    private var shrinkBack: DispatchWorkItem?
    /// Where the fingers have led the lit card, not shown yet (`scrubbed`).
    private var dragging: CGFloat?
    /// How long the grown notch stays once the pictures are at rest.
    private static let lingering: TimeInterval = 0.5
    private static let growth = Animation.easeOut(duration: 0.2)
    /// The notch the pointer is on.
    private var hovered: UUID? {
        didSet {
            guard hovered != oldValue else { return }
            for id in [oldValue, hovered].compactMap({ $0 }) { models[id]?.hovered = id == hovered }
        }
    }

    init(coordinator: StackCoordinator, settings: AppSettings, screens: ScreenProviding, screensNow: @escaping () -> [ScreenInfo],
         cards: @escaping (UUID) -> [IslandWindow], titleWidth: @escaping (UUID) -> CGFloat?) {
        self.coordinator = coordinator
        self.settings = settings
        self.screens = screens
        self.screensNow = screensNow
        self.cards = cards
        self.titleWidth = titleWidth
    }

    /// Keeps the notches above their windows: a window that comes to the front (a click, another app, another window of the zone) goes over its notch, which is put back
    /// on it. Putting a panel above a window asks the window server only, no other app. The pointer is only compared with the notches' rectangles.
    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in self?.restack() }
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] _ in
            self?.restackSoon()
        }
        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .leftMouseUp]) { [weak self] _ in self?.restackSoon() }
        // The pointer in other apps' windows (global), and while one of PaneFlip's own windows is in front (local).
        hoverMonitors = [
            NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] _ in self?.hover(at: NSEvent.mouseLocation) },
            NSEvent.addLocalMonitorForEvents(matching: .mouseMoved) { [weak self] event in
                self?.hover(at: NSEvent.mouseLocation)
                return event
            },
        ].compactMap { $0 }
    }

    func zonesDidChange() {
        guard settings.values.placementEnabled, !coordinator.isScrolling else { return removeAll() }   // the scroll ends with a change of its own
        let current = screensNow()
        var shown = Set<UUID>()
        for stack in coordinator.visibleStacks {
            let zone = screens.flip(stack.rect)
            // A full-screen app has the display: no notches there.
            guard current.contains(where: { $0.desktopNumber != nil && $0.cocoaFrame.contains(CGPoint(x: zone.midX, y: zone.midY)) }) else { continue }
            let size = ZoneNotchView.hoverSize
            let rect = CGRect(x: zone.midX - size.width / 2, y: zone.maxY - size.height, width: size.width, height: size.height)
            let panel = panels[stack.id] ?? make(for: stack.id)
            if stack.id != grown {   // a grown one keeps its place and level until it is back
                if panel.frame != rect { panel.setFrame(rect, display: false) }
                if panel.level != .normal { panel.level = .normal }
            }
            shown.insert(stack.id)
        }
        for id in panels.keys where !shown.contains(id) { remove(id) }
        restack()
    }

    /// Each notch just above the window in front of its zone; none for a zone without a window. A grown one stands above them all.
    /// Not while windows move (a switch, a scroll): putting windows in order meanwhile makes the window server drop frames of what moves; once they are at rest.
    func restack() {
        guard !coordinator.isMoving else { return }
        for (id, panel) in panels where id != grown {
            guard let front = coordinator.stacks[id]?.activeID else { panel.orderOut(nil); continue }
            panel.order(.above, relativeTo: Int(front))
        }
    }

    /// The windows of `zone` are being switched: its notch grows into a row of its open windows, each card as wide as its whole name, up to as wide as the open island
    /// writes a title (a longer one ends in "…"; the widest narrower, only as much as they must, when the zone is too narrow for them all), as tall as the menu bar of
    /// the zone's screen, the one in front lit; above the pictures that slide, until a moment after the switch.
    func showSwitch(of zone: UUID) {
        guard let panel = panels[zone], let model = models[zone], let rect = coordinator.stacks[zone]?.rect else { return }
        defer { shrinkLater() }
        guard grown != zone else { return }
        let open = cards(zone).filter { $0.windowID != nil }
        guard open.count > 1 else { return }
        if grown != nil { collapse() }
        let frame = screens.flip(rect), mid = CGPoint(x: frame.midX, y: frame.midY)
        guard let screen = screensNow().first(where: { $0.cocoaFrame.contains(mid) }) else { return }
        let height = min(screens.menuBarHeight(of: screen), frame.height / 4)
        let most = titleWidth(zone) ?? 100, room = frame.width - 2 * ZoneCorner.radius
        // shortcut: never narrower than a card's picture and room, so a zone too narrow for its windows has the row run past its sides; show the pictures alone if that is seen.
        let widths = CardRow.narrowed(open.map { min(ZoneCardLabel.width(of: $0), ZoneCardLabel.chrome(of: $0) + most) },
                                      narrowest: 2 * ZoneCardLabel.padding + ZoneCardLabel.icon + ZoneCardLabel.spacing) { $0.reduce(0, +) <= room }
        let size = CGSize(width: widths.reduce(0, +), height: height)
        if hovered == zone { hovered = nil }
        grown = zone
        panel.setFrame(CGRect(x: frame.midX - size.width / 2, y: frame.maxY - size.height, width: size.width, height: size.height), display: false)
        // The notch at rest laid out in the larger panel now, where it stands on the screen, so that the growth starts there and not from where it was in the panel.
        panel.contentView?.layoutSubtreeIfNeeded()
        panel.level = .floating   // above the stage the pictures slide on (one level below), below the island
        panel.orderFrontRegardless()
        // One change, after the panel has been drawn at its new size: the cards grow out of the notch at rest.
        DispatchQueue.main.async { [weak self] in
            guard let self, grown == zone else { return }
            // The window in front as it is now (it may have changed meanwhile), the row as it was laid out.
            let now = cards(zone).filter { $0.windowID != nil }, row = now.map(\.id) == open.map(\.id) ? now : open
            withAnimation(Self.growth) {
                model.widths = widths
                model.height = height
                model.lit = Self.front(of: row)
                model.cards = row
            }
        }
    }

    /// Something changed in a zone: while its notch is grown, the lit card slides to the window now in front. Only its place changes: a step costs next to nothing.
    func windowsDidChange(in zone: UUID) {
        guard zone == grown, let model = models[zone], !model.cards.isEmpty else { return }   // still about to grow: it reads the window in front as it grows
        // shortcut: the row is laid out once, as it grows; a window in front that is not in it (one that came meanwhile) ends the row, one that went stays in it
        // until the row ends; lay it out again if that is ever missed.
        guard let front = front(in: zone, among: model.cards) else { return collapse() }
        // On the spring the pictures slide with, from the moment they start: in step with them.
        withAnimation(SlideSpring.animation) { model.lit = front }
    }

    /// The fingers lead the windows of `zone` (`fraction` of a window; to the right is positive, toward the windows before): the lit card of its grown notch follows
    /// them, and goes back to the window in front when they let go.
    func scrubbed(zone: UUID, by fraction: CGFloat) {
        guard zone == grown, let model = models[zone], !model.cards.isEmpty else { return }
        guard fraction != 0 else {
            dragging = nil   // a move still waiting is not for this any more
            if let front = front(in: zone, among: model.cards) { withAnimation(SlideSpring.animation) { model.lit = front } }
            return
        }
        // As the island does: not inside the handling of the finger event, and once for all the events that came meanwhile.
        let queued = dragging != nil
        dragging = fraction
        guard !queued else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self, let fraction = dragging else { return }
            dragging = nil
            guard grown == zone, let front = front(in: zone, among: model.cards) else { return }
            var still = Transaction()
            still.disablesAnimations = true
            withTransaction(still) { model.lit = min(max(front - fraction, 0), CGFloat(model.cards.count - 1)) }
        }
    }

    /// What the wheel and two fingers switch at `point`, as over the open island's row of cards: the windows of the zone whose notch the pointer is on (found as it
    /// moved, `hover`), or whose grown notch it is on, or where that notch stood before it grew, so that a switch the scroll began goes on as the notch grows.
    /// Every scroll event of the system asks: only rectangles are compared.
    func scrollTarget(at point: CGPoint) -> ScrollSwitchTarget? {
        let zone = [grown, hovered].compactMap { $0 }.first { id in
            guard let panel = panels[id] else { return false }
            return notchRect(of: id, in: panel).insetBy(dx: -2, dy: -2).contains(point) || (id == grown && panel.frame.contains(point))
        }
        guard let zone, let stack = coordinator.stacks[zone], stack.tabs.count > 1 else { return nil }
        return .zoneWindows(zone)
    }

    private static func front(of cards: [IslandWindow]) -> CGFloat { CGFloat(cards.firstIndex(where: \.isActive) ?? 0) }

    /// The place of the zone's window in front among the cards of its row, as the zone has it now (the cards are not made again for a step).
    private func front(in zone: UUID, among cards: [IslandWindow]) -> CGFloat? {
        guard let active = coordinator.stacks[zone]?.activeID, let index = cards.firstIndex(where: { $0.windowID == active }) else { return nil }
        return CGFloat(index)
    }

    /// The grown notch goes back a moment after the pictures have come to rest and the pointer is not on it.
    private func shrinkLater() {
        shrinkBack?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self, grown != nil else { return }
            // Not while windows move, nor while the pointer is on the grown notch: it goes back a moment after the pointer has left it.
            if coordinator.isMoving || panels[grown!]?.frame.contains(NSEvent.mouseLocation) == true { shrinkLater() } else { collapse() }
        }
        shrinkBack = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.lingering, execute: work)
    }

    /// The grown notch goes back to rest; then its panel goes back to the notch's place among the windows.
    private func collapse() {
        guard let zone = grown else { return }
        // The pointer may still be where the notch stood lit (the wheel switched): lit again, so that the wheel goes on switching without a move of the pointer.
        let stays = panels[zone].map { notchRect(of: zone, in: $0).insetBy(dx: -2, dy: -2).contains(NSEvent.mouseLocation) } ?? false
        grown = nil
        shrinkBack?.cancel()
        if stays { hovered = zone }
        withAnimation(Self.growth, completionCriteria: .removed) { models[zone]?.cards = [] } completion: { [weak self] in
            // Its panel back to the notch's size, level and place; not while windows slide (then once they are at rest), nor if it was grown again meanwhile.
            guard let self, grown != zone, !coordinator.isMoving else { return }
            zonesDidChange()
        }
    }

    /// Lights the notch under the pointer; not one another window covers there (the pointer is on that window). The frontmost window at the pointer is the notch itself
    /// or, where the notch draws nothing, the zone's own window.
    private func hover(at point: CGPoint) {
        hovered = panels.first { id, panel in
            guard id != grown, panel.isVisible, notchRect(of: id, in: panel).insetBy(dx: -2, dy: -2).contains(point) else { return false }
            let top = NSWindow.windowNumber(at: point, belowWindowWithWindowNumber: 0)
            return top == panel.windowNumber || top == coordinator.stacks[id]?.activeID.map { Int($0) }
        }?.key
    }

    /// Where the notch of `zone` is drawn, in the middle of its panel's top edge: twice as large while the pointer is on it (where it stood so for a grown one).
    private func notchRect(of zone: UUID, in panel: NSPanel) -> CGRect {
        let frame = panel.frame, size = zone == hovered || zone == grown ? ZoneNotchView.hoverSize : ZoneNotchView.size
        return CGRect(x: frame.midX - size.width / 2, y: frame.maxY - size.height, width: size.width, height: size.height)
    }

    /// A press on a notch: at rest, the row of the zone's windows opens (nothing is switched); on a card of the open row, that window comes to the front of its zone
    /// and the focus goes with it, as a click on a card of the open island does.
    private func press(_ zone: UUID, at point: CGPoint) {
        guard grown == zone, let panel = panels[zone], let model = models[zone], !model.cards.isEmpty else { return showSwitch(of: zone) }
        shrinkLater()
        guard let stack = coordinator.stacks[zone], !stack.isParked,
              let index = CardRow.index(atX: point.x - panel.frame.minX, widths: model.widths),
              let id = model.cards[index].windowID else { return }
        if id == stack.activeID { coordinator.focus(zone: zone) } else { coordinator.clickSelect(id, in: stack) }
    }

    /// The window that was clicked or brought forward is raised by its app a moment later.
    /// A press raises the window under it over its notch at once (not when the button is let go): the notch is put back as soon as the window has been raised, and again
    /// for an app that is slow to raise it.
    private func restackSoon() {
        for delay in [0.02, 0.1] { DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in self?.restack() } }
    }

    private func make(for zone: UUID) -> NSPanel {
        let p = NSPanel(contentRect: CGRect(origin: .zero, size: ZoneNotchView.hoverSize), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        p.level = .normal   // among the windows, so that it can stand just above one of them
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = false
        p.hidesOnDeactivate = false
        // AppKit scales a window up (and fades it) when it is ordered in, and down when it goes.
        p.animationBehavior = .none
        p.collectionBehavior = [.canJoinAllSpaces, .stationary]
        let model = ZoneNotchModel()
        let view = ZonePressView()
        view.onPress = { [weak self] point in self?.press(zone, at: point) }
        let host = NSHostingView(rootView: ZoneNotchView(model: model))
        host.sizingOptions = []
        host.autoresizingMask = [.width, .height]
        view.addSubview(host)
        p.contentView = view
        panels[zone] = p
        models[zone] = model
        return p
    }

    private func remove(_ zone: UUID) {
        panels[zone]?.orderOut(nil)
        panels[zone] = nil
        models[zone] = nil
        if hovered == zone { hovered = nil }
        if grown == zone { grown = nil }
    }

    private func removeAll() { for id in Array(panels.keys) { remove(id) } }
}
