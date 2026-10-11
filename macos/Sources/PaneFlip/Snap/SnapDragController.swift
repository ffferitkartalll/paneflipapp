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

    private var monitor: Any?
    private var candidate: (ref: WindowRef, start: CGRect)?
    private var dragging = false
    private var timer: Timer?

    init(windows: WindowSystem, screens: ScreenProviding, coordinator: StackCoordinator,
         settings: AppSettings, keys: KeyStateProviding, overlay: SnapZoneOverlay) {
        self.windows = windows
        self.screens = screens
        self.coordinator = coordinator
        self.settings = settings
        self.keys = keys
        self.overlay = overlay
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

    private var triggerHeld: Bool { settings.snapTrigger.isHeld(using: keys) }

    private func pressed() {
        guard settings.placementEnabled, let hit = windows.windowUnderPointer() else { candidate = nil; return }
        candidate = (hit.ref, hit.frame)
    }

    private func dragged() {
        guard let c = candidate else { return }
        if !dragging {
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
        let held = triggerHeld
        if held && !overlay.isShown {
            overlay.show(zones: coordinator.visibleStacks.map { ($0.id, $0.rect) })
        }
        if !held && overlay.isShown { overlay.hide() }
        if held { overlay.highlight(zone: coordinator.zoneID(at: screens.pointerAX)) }
    }

    private func released() {
        defer { reset() }
        guard dragging, let c = candidate else { return }
        if triggerHeld, let zone = coordinator.zoneID(at: screens.pointerAX) {
            coordinator.snap(c.ref, into: zone)
        } else {
            // Dragged out of its zone without snapping elsewhere: it just leaves the stack. Nothing else is brought
            // to the front; the zone keeps whatever is already there.
            coordinator.unsnap(window: c.ref.id)
        }
    }

    private func reset() {
        timer?.invalidate()
        timer = nil
        candidate = nil
        dragging = false
        overlay.hide()
    }
}
