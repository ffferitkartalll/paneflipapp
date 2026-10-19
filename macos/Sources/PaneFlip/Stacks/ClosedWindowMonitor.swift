import Foundation

/// Watches the windows held by stacks and releases the ones that were closed, so a closed window leaves its zone at once.
final class ClosedWindowMonitor {
    private let coordinator: StackCoordinator
    private let availability: WindowAvailability
    private let screens: ScreenProviding
    private var lastSpaces: Set<UInt64> = []
    private var timer: Timer?

    init(coordinator: StackCoordinator, availability: WindowAvailability, screens: ScreenProviding) {
        self.coordinator = coordinator
        self.availability = availability
        self.screens = screens
    }

    func start(interval: TimeInterval = 0.25) {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in self?.check() }
    }

    func check() {
        let held = coordinator.heldWindows
        // Not while a scroll is moving the windows: asking them is slow then, and they are in flux anyway.
        guard !held.isEmpty, !coordinator.placementOnly(), !coordinator.isScrolling else { return }
        // While the desktop is switching, windows are in flux and would look closed; wait it out.
        let spaces = screens.currentSpaceIDs()
        if spaces != lastSpaces { lastSpaces = spaces; return }

        let snapshot = availability.snapshot()
        let gone = held.filter { availability.isGone($0, in: snapshot) }
        guard !gone.isEmpty else { return }
        // Windows are hidden or rearranged while Mission Control or App Exposé is open: they are not closed.
        // Forget the desktops so the first look after it is the one that waits. (Asked only here: it costs a
        // window list, and nearly every look finds nothing gone.)
        if screens.isMissionControlActive { lastSpaces = []; return }
        gone.forEach { coordinator.release(window: $0.id) }
    }
}
