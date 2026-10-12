import AppKit
import Foundation
import PaneFlipCore

/// Owns the pill panels and decides when each one is visible: while the pointer is over it, briefly after the
/// stack changed, and while it is being used. A Left Shift double tap hides it until the pointer moves away.
final class PillPresenter: ZonePresenting {
    private let coordinator: StackCoordinator
    private let settings: AppSettings
    private let screens: ScreenProviding
    private let iconFont: IconFont

    private var panels: [UUID: PillPanel] = [:]
    private var shown: [UUID: Bool] = [:]
    private var hoverAt: [UUID: Date] = [:]
    private var flashUntil: [UUID: Date] = [:]
    /// Zones whose pill was hidden by a double tap; it stays hidden until the pointer is well clear of it.
    private var suppressed: Set<UUID> = []
    private var timer: Timer?
    private lazy var doubleShift = DoubleTapDetector(keyCode: 56, deviceMask: 0x2) { [weak self] in self?.hideUnderPointer() }

    /// How far the pointer must move away before a hidden pill may come back.
    private let releaseMargin: CGFloat = 48
    private let hideDelay: TimeInterval = 0.4
    private let flashDuration: TimeInterval = 1.5

    init(coordinator: StackCoordinator, settings: AppSettings, screens: ScreenProviding, iconFont: IconFont) {
        self.coordinator = coordinator
        self.settings = settings
        self.screens = screens
        self.iconFont = iconFont
    }

    func start() {
        doubleShift.start()
        timer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { [weak self] _ in self?.update() }
    }

    /// Announce a stack change: show its pill for a moment.
    func flash(zone id: UUID) { flashUntil[id] = Date().addingTimeInterval(flashDuration) }

    // MARK: ZonePresenting

    func zonesDidChange() {
        let visible = coordinator.visibleStacks
        let ids = Set(visible.map(\.id))
        for (id, panel) in panels where !ids.contains(id) {
            panel.orderOut(nil)
            panels[id] = nil
            shown[id] = nil
            hoverAt[id] = nil
            flashUntil[id] = nil
            suppressed.remove(id)
        }
        for stack in visible where panels[stack.id] == nil {
            panels[stack.id] = makePanel(for: stack)
        }
        panels.values.forEach { $0.orderFrontRegardless() }
        update()
    }

    // MARK: Visibility

    /// The pill sits one menu-bar height below the top of the zone, centred, as wide as its segments. The panel
    /// has transparent room around them (the system control collapses into a pop-up without it): only the capsule
    /// inside counts for hovering and clicking. Not limited to the zone: a narrow zone must not squeeze the control.
    private func pillRects(_ stack: ZoneStack, _ panel: PillPanel) -> (frame: CGRect, capsule: CGRect) {
        let w = panel.barWidth
        let frame = CGRect(x: stack.rect.midX - w / 2, y: stack.rect.minY + screens.menuBarThickness, width: w, height: PillMetrics.height)
        return (frame, frame.insetBy(dx: PillPanel.margin, dy: 0))
    }

    private func update() {
        let now = Date(), pointer = screens.pointerAX
        for (id, panel) in panels {
            guard let stack = coordinator.stacks[id] else { continue }
            var show = false, clickable = false
            if stack.tabs.count >= 2 && settings.values.stackingEnabled {
                panel.refresh()
                let (frame, pill) = pillRects(stack, panel)
                // Released only once the pointer is clear of it; forget what was recorded while hidden so it
                // doesn't flash back for a moment after the pointer has left.
                if suppressed.contains(id) && !pill.insetBy(dx: -releaseMargin, dy: -releaseMargin).contains(pointer) {
                    suppressed.remove(id)
                    hoverAt[id] = nil
                    flashUntil[id] = nil
                }
                if pill.contains(pointer) && !suppressed.contains(id) { hoverAt[id] = now }
                let hovering = hoverAt[id].map { now.timeIntervalSince($0) < hideDelay } ?? false
                let flashing = flashUntil[id].map { $0 > now } ?? false
                show = ((hovering || flashing) && !suppressed.contains(id)) || stack.interacting
                // Clicks in the transparent margins go to the windows below.
                clickable = show && (stack.interacting || pill.contains(pointer))
                let screenFrame = screens.flip(frame)
                if panel.frame != screenFrame { panel.setFrame(screenFrame, display: true) }
            }
            panel.ignoresMouseEvents = !clickable
            if shown[id] != show {
                shown[id] = show
                panel.fade(to: show)
            }
        }
    }

    /// Double Left Shift: hide the pill under the pointer so what is behind it can be clicked.
    private func hideUnderPointer() {
        let pointer = screens.pointerAX
        for (id, stack) in coordinator.stacks where shown[id] == true {
            if let panel = panels[id], pillRects(stack, panel).capsule.contains(pointer) { hide(zone: id) }
        }
    }

    /// Hides a zone's pill until the pointer has moved away from it.
    private func hide(zone id: UUID) {
        flashUntil[id] = nil
        suppressed.insert(id)
        update()
    }

    private func makePanel(for stack: ZoneStack) -> PillPanel {
        PillPanel(
            stack: stack, settings: settings, iconFont: iconFont,
            select: { [weak self, weak stack] id in
                if let stack { self?.coordinator.select(id, in: stack) }
            },
            move: { [weak self, weak stack] id, index in
                if let stack { self?.coordinator.move(window: id, to: index, in: stack) }
            },
            hide: { [weak self, weak stack] in
                if let stack { self?.hide(zone: stack.id) }
            })
    }
}
