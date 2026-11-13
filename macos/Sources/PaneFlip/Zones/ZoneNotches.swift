import AppKit
import PaneFlipCore
import SwiftUI

/// Shows a notch at the top inner edge of every zone in view that holds a window (see `ZoneNotchView`). Each notch is a small panel of its own (the window under it is
/// found by its title bar everywhere else), standing just above the window in front of its zone: every window above that one covers the notch too. The notch the pointer is on is lit, and a press on it opens the row of the zone's windows, as a switch does, without switching. While the
/// zone's windows are switched, its notch grows into a row of its open windows, above the pictures that slide, until a moment after the switch. The wheel and two
/// fingers on a notch switch its zone's windows, (`scrollTarget`). While the layout scrolls to the screens beyond the edge there are none.
final class ZoneNotches: ZonePresenting {
    private let coordinator: StackCoordinator
    private let settings: AppSettings
    private let screens: ScreenProviding
    private let screensNow: () -> [ScreenInfo]
    /// The cards of a zone's windows as the island's row has them, and what the island does with them.
    private let source: ZoneCardSource
    private var panels: [UUID: NSPanel] = [:]
    private var models: [UUID: ZoneNotchModel] = [:]
    private var timer: Timer?
    private var mouseMonitor: Any?
    private var hoverMonitors: [Any] = []
    /// The zone whose notch is grown to show a switch of its windows.
    private var grown: UUID?
    private var shrinkBack: DispatchWorkItem?
    /// The zone with the focus when the notches were last laid out: the only zone that has one.
    private var litZone: UUID?
    /// The zone a window of which is being dragged: it has no notch until the drag is over.
    private var draggedZone: UUID?
    /// What puts a notch back at rest after it was lit for a switch, for each zone.
    private var lightEnds: [UUID: DispatchWorkItem] = [:]
    /// Where the fingers have led the lit card, not shown yet (`scrubbed`).
    private var dragging: CGFloat?
    /// A card of the grown notch that the mouse is down on: it is a click if it is let go where it was, else it is carried to another place in the row.
    /// A card or button of the expanded notch that the mouse is down on: done when it is let go on it.
    private var tap: (zone: UUID, index: Int, button: IslandButton?)?
    private var carry: (zone: UUID, card: String, from: CGPoint, grab: CGFloat, centres: [String: CGFloat], moved: Bool)?
    /// How long the grown notch stays once the pictures are at rest.
    private static let lingering: TimeInterval = 0.5
    private static let growth = Animation.easeOut(duration: 0.2)
    /// The notch lit under the pointer, and at rest again.
    private static let lifting = Animation.easeOut(duration: 0.15)
    /// A notch shows cards: the island asks for the Dock's badges for them.
    var showsCards: Bool { grown != nil }

    /// The Dock's badges changed: the cards shown take them (the same cards, in the same order), and the row is as wide as they now ask, as a movement: a badge that went
    /// fades and its room closes, one that came makes room (the panel, as large as the row can be, grows first).
    func badgesDidChange() {
        guard let zone = grown, let model = models[zone], !model.cards.isEmpty else { return }
        let open = source.cards(of: zone)
        let openSame = open.map(\.id) == model.cards.map(\.id), all = source.allCards(of: zone)
        let slotsSame = !model.slots.isEmpty && all.map(\.id) == model.slots.map(\.id)
        guard (openSame && open != model.cards) || (slotsSame && all != model.slots) else { return }
        var widths = model.widths
        if openSame, carry == nil, let rect = coordinator.stacks[zone]?.rect, let panel = panels[zone], open.allSatisfy({ $0.windowID != nil }) {
            widths = rowWidths(of: open, in: zone, zoneWidth: screens.flip(rect).width)
            widen(panel, for: widths, height: model.height)
        }
        withAnimation(Self.growth) {
            if openSame { model.cards = open; model.widths = widths }
            if slotsSame { model.slots = all }
        }
    }

    /// The panel as wide as the row needs (never narrower than it is), around the same middle.
    private func widen(_ panel: NSPanel, for widths: [CGFloat], height: CGFloat) {
        let wide = widths.reduce(0, +) + height, frame = panel.frame
        if wide > frame.width { panel.setFrame(CGRect(x: frame.midX - wide / 2, y: frame.minY, width: wide, height: frame.height), display: false) }
    }

    /// The notch the pointer is on.
    private var hovered: UUID? {
        didSet {
            guard hovered != oldValue else { return }
            // Lit, or at rest again, as a movement; not while it is grown (its cards stand for it) or turns back (`collapse` ends that).
            for id in [oldValue, hovered].compactMap({ $0 }) where models[id]?.cards.isEmpty ?? false {
                withAnimation(Self.lifting) { models[id]?.lift = id == hovered ? 1 : 0 }
            }
        }
    }

    init(coordinator: StackCoordinator, settings: AppSettings, screens: ScreenProviding, screensNow: @escaping () -> [ScreenInfo],
         source: ZoneCardSource) {
        self.coordinator = coordinator
        self.settings = settings
        self.screens = screens
        self.screensNow = screensNow
        self.source = source
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

    /// The windows of `zone` are being switched (a shortcut, the wheel, the fingers): its notch grows into the row of its windows, or, if it opens on a click only, stays
    /// closed, lit as it is with the pointer on it for the moment of the switch if that is asked for.
    func switched(in zone: UUID) {
        let values = settings.values
        switch NotchSwitchResponse.of(opensOnClickOnly: values.notchOpensOnClickOnly, liftsOnSwitch: values.notchLiftsOnSwitch, grown: grown == zone) {
        case .grow: showSwitch(of: zone)
        case .lift: keepForSwitch(zone, lit: true)
        case .stay: keepForSwitch(zone, lit: false)
        }
    }

    /// The notch stays closed for a switch: above the stage the pictures slide on (they would cover it), lit as with the pointer on it if asked for; the lit part follows
    /// the windows (`follow`). A moment after the switch it is put back (`endSwitch`).
    private func keepForSwitch(_ zone: UUID, lit: Bool) {
        guard let panel = panels[zone], let model = models[zone], grown == nil, model.cards.isEmpty else { return }
        panel.level = .floating
        panel.orderFrontRegardless()
        if lit { withAnimation(Self.lifting) { model.lift = 1 } }
        endSwitch(of: zone)
    }

    private func endSwitch(of zone: UUID) {
        lightEnds[zone]?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            if coordinator.isMoving { return endSwitch(of: zone) }   // not while the windows still move
            lightEnds[zone] = nil
            guard let panel = panels[zone], let model = models[zone], model.cards.isEmpty else { return }
            // The pointer on the notch keeps it lit (`hovered`).
            if hovered != zone { withAnimation(Self.lifting) { model.lift = 0 } }
            panel.level = .normal
            restack()
        }
        lightEnds[zone] = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.lingering, execute: work)
    }

    /// The window in front of the zone changed: the lit part of the notch slides to it, on the spring the pictures slide with. (The grown notch has its own cards:
    /// `windowsDidChange`.)
    private func follow(_ stack: ZoneStack, in model: ZoneNotchModel) {
        guard let index = stack.tabs.firstIndex(where: { $0.id == stack.activeID }), model.activeIndex != index else { return }
        model.activeIndex = index
        if model.cards.isEmpty { withAnimation(SlideSpring.animation) { model.lit = CGFloat(index) } }
    }

    /// A window is being dragged out of `zone`, or the drag is over (nil).
    func windowDragged(from zone: UUID?) {
        guard draggedZone != zone else { return }
        draggedZone = zone
        zonesDidChange()
    }

    func zonesDidChange() {
        litZone = coordinator.focusedZoneID
        guard settings.values.placementEnabled, !coordinator.isScrolling else { return removeAll() }   // the scroll ends with a change of its own
        let current = screensNow()
        var shown = Set<UUID>()
        // Only the zone with the focus has a notch, on whichever display (and the one that is grown, until it is back).
        let wanted = NotchVisibility.zones(among: coordinator.visibleStacks.map(\.id), focused: litZone, grown: grown, dragged: draggedZone)
        for stack in coordinator.visibleStacks where wanted.contains(stack.id) {
            let zone = screens.flip(stack.rect)
            // A full-screen app has the display: no notches there.
            guard current.contains(where: { $0.desktopNumber != nil && $0.cocoaFrame.contains(CGPoint(x: zone.midX, y: zone.midY)) }) else { continue }
            let panel = panels[stack.id] ?? make(for: stack.id)
            if let model = models[stack.id] {
                let index = stack.tabs.firstIndex { $0.id == stack.activeID } ?? 0
                let resized = model.windowCount != stack.tabs.count
                model.windowCount = stack.tabs.count
                model.activeIndex = index
                if resized, model.cards.isEmpty { model.lit = CGFloat(index) }   // new, or a window came or went: the lit part stands on the window in front at once
            }
            let size = NotchSize.hoverSize(forWindows: stack.tabs.count)
            let rect = CGRect(x: zone.midX - size.width / 2, y: zone.maxY - size.height, width: size.width, height: size.height)
            if stack.id != grown, models[stack.id]?.cards.isEmpty ?? true {   // a grown one keeps its place and level until it is back (until its cards have turned back into the parts)
                if panel.frame != rect { panel.setFrame(rect, display: false) }
                if panel.level != .normal && lightEnds[stack.id] == nil { panel.level = .normal }   // not while it stands above the stage for a switch
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
        if coordinator.focusedZoneID != litZone { return zonesDidChange() }   // the focus went to another zone: the notch goes with it
        for (id, panel) in panels where id != grown && lightEnds[id] == nil {
            guard let front = coordinator.stacks[id]?.activeID else { panel.orderOut(nil); continue }
            if models[id]?.windowCount != coordinator.stacks[id]?.tabs.count { return zonesDidChange() }   // a window came or went: the notch is as wide as they ask
            if let stack = coordinator.stacks[id], let model = models[id] { follow(stack, in: model) }
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
        let open = source.cards(of: zone).filter { $0.windowID != nil }
        guard !open.isEmpty else { return }
        if grown != nil { collapse() }
        let frame = screens.flip(rect), mid = CGPoint(x: frame.midX, y: frame.midY)
        guard let screen = screensNow().first(where: { $0.cocoaFrame.contains(mid) }) else { return }
        let height = min(screens.menuBarHeight(of: screen), frame.height / 4)
        let widths = rowWidths(of: open, in: zone, zoneWidth: frame.width)
        let size = CGSize(width: widths.reduce(0, +) + height, height: height)   // and the button at its end, as wide as the row is tall
        grown = zone
        source.refreshBadges()   // only now: it asks while a notch shows cards, and the badges of the last look may be old
        panel.setFrame(CGRect(x: frame.midX - size.width / 2, y: frame.maxY - size.height, width: size.width, height: size.height), display: false)
        // The notch at rest laid out in the larger panel now, where it stands on the screen, so that the growth starts there and not from where it was in the panel.
        panel.contentView?.layoutSubtreeIfNeeded()
        panel.level = .floating   // above the stage the pictures slide on (one level below), below the island
        panel.orderFrontRegardless()
        // One change, after the panel has been drawn at its new size: the cards grow out of the notch at rest.
        DispatchQueue.main.async { [weak self] in
            guard let self, grown == zone else { return }
            // The window in front as it is now (it may have changed meanwhile), the row as it was laid out.
            let now = source.cards(of: zone).filter { $0.windowID != nil }, row = now.map(\.id) == open.map(\.id) ? now : open
            // A badge that came since the row was laid out makes room before the cards grow, not after.
            let fitted = row == open ? widths : rowWidths(of: row, in: zone, zoneWidth: frame.width)
            widen(panel, for: fitted, height: height)
            withAnimation(Self.growth) {
                model.widths = fitted
                model.height = height
                model.lit = Self.front(of: row)
                model.cards = row
                model.grow = 1
                model.lift = 1
            }
            hoverCard(at: NSEvent.mouseLocation)   // the pointer may be on a card already
        }
    }

    /// How wide each card of the row is: as wide as its whole name, up to as wide as the open island writes a title, the widest narrower when the zone is too narrow.
    private func rowWidths(of open: [IslandWindow], in zone: UUID, zoneWidth: CGFloat) -> [CGFloat] {
        let most = source.titleWidth(of: zone) ?? 100, room = zoneWidth - 2 * ZoneCorner.radius
        // shortcut: never narrower than a card's picture and room, so a zone too narrow for its windows has the row run past its sides; show the pictures alone if that is seen.
        return CardRow.narrowed(open.map { min(ZoneCardLabel.width(of: $0), ZoneCardLabel.chrome(of: $0) + most) },
                                narrowest: open.map { 2 * ZoneCardLabel.padding + ZoneCardLabel.icon + ZoneCardLabel.spacing + ZoneCardLabel.badgeRoom(of: $0) }) { $0.reduce(0, +) <= room }
    }

    /// Something changed in a zone: while its notch is grown, the lit card slides to the window now in front. Only its place changes: a step costs next to nothing.
    func windowsDidChange(in zone: UUID) {
        if zone != grown, let stack = coordinator.stacks[zone], let model = models[zone] { return follow(stack, in: model) }
        guard zone == grown, let model = models[zone], !model.cards.isEmpty else { return }   // still about to grow: it reads the window in front as it grows
        refreshSlots(of: zone)
        // shortcut: the row is laid out once, as it grows; a window in front that is not in it (one that came meanwhile) ends the row, one that went stays in it
        // until the row ends; lay it out again if that is ever missed.
        guard let front = front(in: zone, among: model.cards) else { return collapse() }
        // On the spring the pictures slide with, from the moment they start: in step with them.
        withAnimation(SlideSpring.animation) { model.lit = front }
    }

    /// The fingers lead the windows of `zone` (`fraction` of a window; to the right is positive, toward the windows before): the lit card of its grown notch follows
    /// them, and goes back to the window in front when they let go.
    func scrubbed(zone: UUID, by fraction: CGFloat) {
        if zone != grown { return scrubbedClosed(zone, by: fraction) }
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

    /// The same for a notch that is not grown: its lit part follows the fingers.
    private func scrubbedClosed(_ zone: UUID, by fraction: CGFloat) {
        guard let model = models[zone], model.cards.isEmpty else { return }
        guard fraction != 0 else { return withAnimation(SlideSpring.animation) { model.lit = CGFloat(model.activeIndex) } }
        var still = Transaction()
        still.disablesAnimations = true
        withTransaction(still) { model.lit = min(max(CGFloat(model.activeIndex) - fraction, 0), CGFloat(max(model.windowCount - 1, 0))) }
    }

    /// What the wheel and two fingers switch at `point`: the windows of the zone whose notch the pointer is on (found as it
    /// moved, `hover`), or whose grown notch it is on, or where that notch stood before it grew, so that a switch the scroll began goes on as the notch grows.
    /// Every scroll event of the system asks: only rectangles are compared.
    func scrollTarget(at point: CGPoint) -> ScrollSwitchTarget? {
        let zone = [grown, hovered].compactMap { $0 }.first { id in
            guard let panel = panels[id] else { return false }
            return notchRect(of: id, in: panel).insetBy(dx: -2, dy: -2).contains(point) || (id == grown && panel.frame.contains(point))
        }
        guard let zone, zone == coordinator.focusedZoneID, let stack = coordinator.stacks[zone], stack.tabs.count > 1 else { return nil }   // only the zone with the focus switches
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
        models[zone]?.hoveredCard = nil
        models[zone]?.carriedCard = nil
        // Expanded: the cards go back into the compact row first.
        let shrink = { [weak self] in
            guard let self, let model = models[zone] else { return }
            model.slots = []
            model.hoveredSlot = nil
            model.hoveredButton = nil
            model.moreHovered = false
            collapseCompact(zone)
        }
        guard let model = models[zone], model.expand > 0 else { return shrink() }
        if let panel = panels[zone] {   // large enough for the compact row again
            let compact = CGSize(width: model.widths.reduce(0, +) + model.height, height: model.height), frame = panel.frame
            let wide = max(frame.width, compact.width)
            panel.setFrame(CGRect(x: frame.midX - wide / 2, y: frame.maxY - frame.height, width: wide, height: frame.height), display: false)
        }
        withAnimation(Self.growth, completionCriteria: .removed) { model.expand = 0 } completion: { shrink() }
    }

    /// The compact row's way back: first the cards turn back into the parts of the notch, then the notch is at rest.
    private func collapseCompact(_ zone: UUID) {
        // The cards turn back into the parts of the notch (the notch the pointer was on), then, if the pointer is gone, that goes back to the notch at rest: the way it grew,
        // backwards. Only then are the cards taken away, which changes nothing that is seen.
        withAnimation(Self.growth, completionCriteria: .removed) { models[zone]?.grow = 0 } completion: { [weak self] in
            guard let self, grown != zone, let model = models[zone] else { return }
            let finish = { [weak self] in
                guard let self, grown != zone else { return }
                model.cards = []
                // Its panel back to the notch's size, level and place; not while windows slide (then once they are at rest), nor if it was grown again meanwhile.
                guard !coordinator.isMoving else { return }
                zonesDidChange()
            }
            let lift: CGFloat = hovered == zone ? 1 : 0
            if model.lift == lift { return finish() }
            withAnimation(Self.lifting, completionCriteria: .removed) { model.lift = lift } completion: { finish() }
        }
    }

    /// Lights the notch under the pointer; not one another window covers there (the pointer is on that window). The frontmost window at the pointer is the notch itself
    /// or, where the notch draws nothing, the zone's own window.
    private func hover(at point: CGPoint) {
        hoverCard(at: point)
        hovered = panels.first { id, panel in
            guard id != grown, panel.isVisible, notchRect(of: id, in: panel).insetBy(dx: -2, dy: -2).contains(point) else { return false }
            let top = NSWindow.windowNumber(at: point, belowWindowWithWindowNumber: 0)
            return top == panel.windowNumber || top == coordinator.stacks[id]?.activeID.map { Int($0) }
        }?.key
    }

    /// The card of the grown notch under the pointer is tinted (unless it is the lit one: `ZoneNotchRow`); the "more" button and, expanded, the cards and their buttons light up.
    private func hoverCard(at point: CGPoint) {
        guard let zone = grown, let panel = panels[zone], let model = models[zone] else { return }
        if !model.slots.isEmpty {
            let hit = expandedHit(zone, at: point)
            if model.hoveredSlot != hit?.index { model.hoveredSlot = hit?.index }
            if model.hoveredButton != hit?.button { model.hoveredButton = hit?.button }
            return
        }
        let inside = panel.frame.contains(point)
        let card = inside ? CardRow.index(atX: point.x - panel.frame.minX, widths: model.widths) : nil
        if model.hoveredCard != card { model.hoveredCard = card }
        let cardsEnd = panel.frame.minX + model.widths.reduce(0, +)
        let more = inside && point.x >= cardsEnd && point.x < cardsEnd + model.height
        if model.moreHovered != more { model.moreHovered = more }
    }

    // MARK: Expanded

    /// The notch expands into the island's row of cards: every slot of the zone, with the buttons of a card under the pointer, as the island's row has them.
    private func expand(_ zone: UUID) {
        guard let panel = panels[zone], let model = models[zone], model.slots.isEmpty, let rect = coordinator.stacks[zone]?.rect else { return }
        let slots = source.allCards(of: zone)
        guard !slots.isEmpty else { return }
        let cardWidth = ZoneNotchExpanded.cardWidth(island: source.titleWidth(of: zone) ?? 100, count: slots.count, zoneWidth: screens.flip(rect).width)
        let size = ZoneNotchExpanded.size(count: slots.count, cardWidth: cardWidth), frame = panel.frame
        model.slots = slots
        model.cardWidth = cardWidth
        model.moreHovered = false
        model.hoveredSlot = model.hoveredCard.flatMap { index in model.cards.indices.contains(index) ? slots.firstIndex { $0.id == model.cards[index].id } : nil }
        // The panel as large as both; the compact row is drawn in it as before, then goes out as the cards come in.
        let wide = max(size.width, frame.width)
        panel.setFrame(CGRect(x: frame.midX - wide / 2, y: frame.maxY - size.height, width: wide, height: max(size.height, frame.height)), display: false)
        panel.contentView?.layoutSubtreeIfNeeded()
        DispatchQueue.main.async { [weak self] in
            guard let self, grown == zone else { return }
            withAnimation(Self.growth, completionCriteria: .removed) { model.expand = 1 } completion: { [weak self] in
                // Its panel as large as the cards, not larger: the mouse goes through what it does not draw.
                guard let self, grown == zone, model.expand == 1, let panel = panels[zone] else { return }
                panel.setFrame(CGRect(x: panel.frame.midX - size.width / 2, y: panel.frame.maxY - size.height, width: size.width, height: size.height), display: false)
            }
        }
    }

    /// Where the expanded notch is drawn: in the middle of its panel's top edge.
    private func expandedFrame(_ zone: UUID) -> CGRect? {
        guard let panel = panels[zone], let model = models[zone], !model.slots.isEmpty else { return nil }
        let size = ZoneNotchExpanded.size(count: model.slots.count, cardWidth: model.cardWidth)
        return CGRect(x: panel.frame.midX - size.width / 2, y: panel.frame.maxY - size.height, width: size.width, height: size.height)
    }

    /// The card of the expanded notch at `point` and the button of it that is there, if any.
    private func expandedHit(_ zone: UUID, at point: CGPoint) -> (index: Int, button: IslandButton?)? {
        guard let model = models[zone], let frame = expandedFrame(zone), frame.contains(point),
              let index = ZoneNotchExpanded.index(atX: point.x - frame.minX, count: model.slots.count, cardWidth: model.cardWidth) else { return nil }
        let card = ZoneNotchExpanded.pictureSize(width: model.cardWidth), slot = model.slots[index]
        let left = frame.minX + CGFloat(index) * model.cardWidth, top = frame.maxY
        func screenRect(_ rect: CGRect) -> CGRect { CGRect(x: left + rect.minX, y: top - rect.maxY, width: rect.width, height: rect.height) }
        guard slot.hasButtons, point.y <= top, point.y >= top - card.height else { return (index, nil) }
        for (action, rect) in IslandCardAction.rects(in: card, among: slot.actions) where screenRect(rect).contains(point) { return (index, .card(action, slot.id)) }
        if screenRect(IslandCardAction.selectRect(in: card)).contains(point) { return (index, .select(slot.id)) }
        return (index, nil)
    }

    private func pressExpanded(_ zone: UUID, at point: CGPoint) {
        guard let hit = expandedHit(zone, at: point), let model = models[zone], let frame = expandedFrame(zone) else { return }
        tap = (zone, hit.index, hit.button)
        // A card (not one of its buttons) is held: let go where it was, it is clicked; carried, it changes place.
        guard hit.button == nil else { return }
        let centres = Dictionary(uniqueKeysWithValues: model.slots.enumerated().map { ($1.id, (CGFloat($0) + 0.5) * model.cardWidth) })
        let card = model.slots[hit.index]
        carry = (zone, card.id, point, point.x - frame.minX - (centres[card.id] ?? 0), centres, false)
    }

    /// The mouse is let go: what was pressed is done if it is let go on it (a button of the card, else the card).
    private func releaseExpanded(_ pressed: (zone: UUID, index: Int, button: IslandButton?)) {
        tap = nil
        guard let model = models[pressed.zone], model.slots.indices.contains(pressed.index),
              let hit = expandedHit(pressed.zone, at: NSEvent.mouseLocation), hit.index == pressed.index, hit.button == pressed.button else { return }
        let slot = model.slots[pressed.index]
        switch pressed.button {
        case .card(let action, _): source.perform(action, on: slot, in: pressed.zone)
        case .select: source.toggleStart(slot, in: pressed.zone)
        default: source.choose(slot, in: pressed.zone)
        }
        refreshSlots(of: pressed.zone)
    }

    /// The cards as the zone has them now (a window that came or went, a tick), as long as there are as many.
    private func refreshSlots(of zone: UUID) {
        guard let model = models[zone], !model.slots.isEmpty else { return }
        let now = source.allCards(of: zone)
        if now.count == model.slots.count, now != model.slots { withAnimation(SlideSpring.animation) { model.slots = now } }
    }

    /// Where the notch of `zone` is drawn, in the middle of its panel's top edge: twice as large while the pointer is on it (where it stood so for a grown one).
    private func notchRect(of zone: UUID, in panel: NSPanel) -> CGRect {
        let frame = panel.frame, count = models[zone]?.windowCount ?? 1
        let size = zone == hovered || zone == grown ? NotchSize.hoverSize(forWindows: count) : NotchSize.size(forWindows: count)
        return CGRect(x: frame.midX - size.width / 2, y: frame.maxY - size.height, width: size.width, height: size.height)
    }

    /// A press on a notch: at rest, the row of the zone's windows opens (nothing is switched); on a card of the open row, the card is held: let go where it was, its
    /// window comes to the front of its zone and the focus goes with it (`release`), as a click on a card of the open island does; carried, it changes place in the row.
    private func press(_ zone: UUID, at point: CGPoint) {
        guard grown == zone, let panel = panels[zone], let model = models[zone], !model.cards.isEmpty else { return showSwitch(of: zone) }
        shrinkLater()
        if !model.slots.isEmpty { return pressExpanded(zone, at: point) }
        let cardsEnd = panel.frame.minX + model.widths.reduce(0, +)
        if point.x >= cardsEnd, point.x < cardsEnd + model.height { return expand(zone) }
        guard let index = CardRow.index(atX: point.x - panel.frame.minX, widths: model.widths) else { return }
        var centres: [String: CGFloat] = [:], edge: CGFloat = 0
        for (card, width) in zip(model.cards, model.widths) {
            centres[card.id] = edge + width / 2
            edge += width
        }
        let card = model.cards[index]
        carry = (zone, card.id, point, point.x - panel.frame.minX - (centres[card.id] ?? 0), centres, false)
    }

    /// The mouse moves with a card held: the card goes to the place where its middle is, among the others (measured as the row lay when the mouse went down).
    private func drag(to point: CGPoint) {
        guard var current = carry, let panel = panels[current.zone], let model = models[current.zone] else { return }
        if !current.moved && hypot(point.x - current.from.x, point.y - current.from.y) < 4 { return }
        if !model.slots.isEmpty { return dragExpanded(current, to: point, panel: panel, model: model) }
        if !current.moved { (panel.contentView as? ZonePressView)?.cursor = .closedHand }   // the card is in the hand until it is let go
        current.moved = true
        carry = current
        shrinkLater()
        guard let from = model.cards.firstIndex(where: { $0.id == current.card }) else { return }
        let centre = point.x - panel.frame.minX - current.grab
        // The card floats where the mouse has it, inside the notch.
        var still = Transaction()
        still.disablesAnimations = true
        withTransaction(still) {
            model.carriedCard = current.card
            // No edge of the card goes past the notch's.
            let half = (model.cards.firstIndex { $0.id == current.card }.map { model.widths[$0] } ?? 0) / 2
            model.carriedX = min(max(centre, half), model.widths.reduce(0, +) - half)
        }
        let to = model.cards.filter { $0.id != current.card }.filter { (current.centres[$0.id] ?? 0) < centre }.count
        guard to != from, let rect = coordinator.stacks[current.zone]?.rect else { return }
        source.move(model.cards[from], toPlaceOf: model.cards[to], in: current.zone)
        let open = source.cards(of: current.zone).filter { $0.windowID != nil }
        guard open.count == model.cards.count else { return }
        withAnimation(Self.growth) {
            model.cards = open
            model.widths = rowWidths(of: open, in: current.zone, zoneWidth: screens.flip(rect).width)
            model.lit = Self.front(of: open)
            model.hoveredCard = open.firstIndex { $0.id == current.card }
        }
    }

    /// The same in the expanded notch: the card floats with the mouse, the cards of the island's row make room, and the zone's windows stand in the new order.
    private func dragExpanded(_ held: (zone: UUID, card: String, from: CGPoint, grab: CGFloat, centres: [String: CGFloat], moved: Bool), to point: CGPoint, panel: NSPanel, model: ZoneNotchModel) {
        var current = held
        if !current.moved { (panel.contentView as? ZonePressView)?.cursor = .closedHand }
        current.moved = true
        carry = current
        shrinkLater()
        guard let frame = expandedFrame(current.zone), let from = model.slots.firstIndex(where: { $0.id == current.card }) else { return }
        let centre = point.x - frame.minX - current.grab
        var still = Transaction()
        still.disablesAnimations = true
        withTransaction(still) {
            model.carriedCard = current.card
            // No edge of the card goes past the notch's.
            model.carriedX = min(max(centre, model.cardWidth / 2), frame.width - model.cardWidth / 2)
        }
        let to = model.slots.filter { $0.id != current.card }.filter { (current.centres[$0.id] ?? 0) < centre }.count
        guard to != from, let rect = coordinator.stacks[current.zone]?.rect else { return }
        source.move(model.slots[from], toPlaceOf: model.slots[to], in: current.zone)
        let now = source.allCards(of: current.zone), open = now.filter { $0.windowID != nil }
        guard now.count == model.slots.count, open.count == model.cards.count else { return }
        withAnimation(Self.growth) {
            model.slots = now
            model.cards = open
            model.widths = rowWidths(of: open, in: current.zone, zoneWidth: screens.flip(rect).width)
            model.lit = Self.front(of: open)
            model.hoveredSlot = now.firstIndex { $0.id == current.card }
        }
    }

    /// The mouse is let go: a card held where it was is clicked.
    private func release() {
        guard let current = carry else {
            if let pressed = tap { releaseExpanded(pressed) }
            return
        }
        carry = nil
        // A card carried goes to its place, and is put down (nothing else is done).
        if current.moved { tap = nil }
        if current.moved, let model = models[current.zone], !model.slots.isEmpty, let index = model.slots.firstIndex(where: { $0.id == current.card }) {
            (panels[current.zone]?.contentView as? ZonePressView)?.cursor = nil
            withAnimation(Self.growth) { model.carriedX = (CGFloat(index) + 0.5) * model.cardWidth }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak model] in
                if model?.carriedCard == current.card { model?.carriedCard = nil }
            }
            return
        }
        // Not carried, in the expanded notch: a click on the card.
        if !current.moved, let model = models[current.zone], !model.slots.isEmpty, let pressed = tap { return releaseExpanded(pressed) }
        // A card carried goes to its place, and is put down.
        if current.moved { (panels[current.zone]?.contentView as? ZonePressView)?.cursor = nil }
        if current.moved, let model = models[current.zone], let index = model.cards.firstIndex(where: { $0.id == current.card }) {
            withAnimation(Self.growth) { model.carriedX = model.widths[..<index].reduce(0, +) + model.widths[index] / 2 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak model] in
                if model?.carriedCard == current.card { model?.carriedCard = nil }
            }
        }
        guard !current.moved, let model = models[current.zone], let stack = coordinator.stacks[current.zone], !stack.isParked,
              let id = model.cards.first(where: { $0.id == current.card })?.windowID else { return }
        if id == stack.activeID { coordinator.focus(zone: current.zone) } else { coordinator.clickSelect(id, in: stack) }
    }

    /// The window that was clicked or brought forward is raised by its app a moment later.
    /// A press raises the window under it over its notch at once (not when the button is let go): the notch is put back as soon as the window has been raised, and again
    /// for an app that is slow to raise it.
    private func restackSoon() {
        for delay in [0.02, 0.1] { DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in self?.restack() } }
    }

    private func make(for zone: UUID) -> NSPanel {
        let p = NSPanel(contentRect: CGRect(origin: .zero, size: NotchSize.hoverSize(forWindows: 1)), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
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
        view.onDrag = { [weak self] point in self?.drag(to: point) }
        view.onRelease = { [weak self] _ in self?.release() }
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
        lightEnds[zone]?.cancel()
        lightEnds[zone] = nil
        if hovered == zone { hovered = nil }
        if grown == zone { grown = nil }
    }

    private func removeAll() { for id in Array(panels.keys) { remove(id) } }
}
