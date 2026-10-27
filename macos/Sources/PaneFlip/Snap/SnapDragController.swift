import AppKit
import PaneFlipCore

/// Watches window drags. While the snap trigger is held during a drag the zones light up; releasing the mouse
/// over a zone snaps the window in, releasing elsewhere takes a stacked window out of its zone.
final class SnapDragController {
    private let windows: WindowSystem
    private let screens: ScreenProviding
    private let coordinator: StackCoordinator
    private let settings: AppSettings
    private let keys: KeyStateProviding
    private let overlay: SnapZoneOverlay
    private let island: ZoneDropTarget

    private var monitor: Any?
    private var candidate: (ref: WindowRef, start: CGRect)?
    private var dragging = false
    private var pressedAt = Date.distantPast
    private var lastCheck = Date.distantPast
    private var timer: Timer?

    init(windows: WindowSystem, screens: ScreenProviding, coordinator: StackCoordinator,
         settings: AppSettings, keys: KeyStateProviding, overlay: SnapZoneOverlay, island: ZoneDropTarget) {
        self.windows = windows
        self.screens = screens
        self.coordinator = coordinator
        self.settings = settings
        self.keys = keys
        self.overlay = overlay
        self.island = island
    }

    func start() {
        monitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .leftMouseDragged, .leftMouseUp]) { [weak self] event in
            switch event.type {
            case .leftMouseDown: self?.pressed()
            case .leftMouseDragged: self?.dragged()
            default: self?.released()
            }
        }
    }

    private var snapOn: Bool { settings.values.snapTrigger.isHeld(using: keys) }

    private func pressed() {
        guard settings.values.placementEnabled, let hit = windows.windowUnderPointer() else { candidate = nil; return }
        candidate = (hit.ref, hit.frame)
        pressedAt = Date()
        lastCheck = .distantPast
    }

    private func dragged() {
        guard let c = candidate else { return }
        if !dragging {
            // A window drag starts at once and moves the window. Anything else (selecting text, a slider) is not
            // worth asking the other app about on every mouse event: give up after a second, ask at most 20×/s.
            let now = Date()
            if now.timeIntervalSince(pressedAt) > 1 { candidate = nil; return }
            guard now.timeIntervalSince(lastCheck) > 0.05 else { return }
            lastCheck = now
            // A drag only counts once the window itself moved (not resized, not a click inside it).
            guard let f = windows.frame(of: c.ref),
                  hypot(f.minX - c.start.minX, f.minY - c.start.minY) > 4,
                  abs(f.width - c.start.width) < 2, abs(f.height - c.start.height) < 2 else { return }
            dragging = true
            timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in self?.updateOverlay() }
        }
        updateOverlay()
    }

    private func updateOverlay() {
        island.dragMoved(to: NSEvent.mouseLocation)
        let held = snapOn
        if held && !overlay.isShown {
            overlay.show(zones: coordinator.dropStacks.map { ($0.id, $0.rect) })
        }
        if !held && overlay.isShown { overlay.hide() }
        if held { overlay.highlight(zone: coordinator.zoneID(at: screens.pointerAX, forDrop: true)) }
    }

    private func released() {
        defer { reset() }
        guard dragging, let c = candidate else { return }
        // On the island in the menu bar: dropped on one of its zones the window goes there; anywhere else on it nothing happens.
        let pointer = NSEvent.mouseLocation
        if island.isOver(pointer) {
            island.drop(c.ref, at: pointer)
            return
        }
        if snapOn, let zone = coordinator.zoneID(at: screens.pointerAX, forDrop: true) {
            coordinator.snap(c.ref, into: zone)
        } else {
            // Dragged out of its zone without snapping elsewhere: it just leaves the stack. Nothing else is brought
            // to the front; the zone keeps whatever is already there.
            coordinator.takeOut(c.ref, grabbedAt: screens.pointerAX)
        }
    }

    private func reset() {
        let wasDragging = dragging
        timer?.invalidate()
        timer = nil
        candidate = nil
        dragging = false
        overlay.hide()
        if wasDragging { island.dragEnded() }   // a plain click on the island is no drag: it stays open
    }
}
