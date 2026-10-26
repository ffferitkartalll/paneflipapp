import CoreGraphics
import Foundation

/// Watches the windows held by stacks and releases the ones that were closed, so a closed window leaves its zone at once.
/// The system window list is read off the main thread (one look at a time); what the answer means is decided on the main
/// thread, after checking that nothing moved or changed in the meantime.
final class ClosedWindowMonitor {
    private let coordinator: StackCoordinator
    private let availability: WindowAvailability
    private let screens: ScreenProviding
    private let background: (@escaping () -> Void) -> Void
    private let onMain: (@escaping () -> Void) -> Void
    private var lastSpaces: Set<UInt64> = []
    private var timer: Timer?
    private var isLooking = false

    init(coordinator: StackCoordinator, availability: WindowAvailability, screens: ScreenProviding,
         background: @escaping (@escaping () -> Void) -> Void = { DispatchQueue.global(qos: .utility).async(execute: $0) },
         onMain: @escaping (@escaping () -> Void) -> Void = { DispatchQueue.main.async(execute: $0) }) {
        self.coordinator = coordinator
        self.availability = availability
        self.screens = screens
        self.background = background
        self.onMain = onMain
    }

    func start(interval: TimeInterval = 0.25) {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in self?.check() }
    }

    func check() {
        // A slow list never stacks a second one; a tick during a scroll is skipped (the next one catches up).
        guard !isLooking else { return }
        let held = coordinator.heldWindows
        guard !held.isEmpty, !coordinator.placementOnly(), !coordinator.isMoving else { return }
        // While the desktop is switching, windows are in flux and would look closed; wait it out.
        let spaces = screens.currentSpaceIDs()
        if spaces != lastSpaces { lastSpaces = spaces; return }

        isLooking = true
        background { [self] in
            let sets = availability.windowSets()
            onMain { [self] in finish(looked: held, sets: sets, spaces: spaces) }
        }
    }

    private func finish(looked: [WindowRef], sets: (all: Set<CGWindowID>, onScreen: Set<CGWindowID>), spaces: Set<UInt64>) {
        isLooking = false
        // The list is old by now: drop it when the windows are moving, the desktops changed, or the stacks changed under it.
        guard !coordinator.isMoving, !coordinator.placementOnly(), screens.currentSpaceIDs() == spaces else { return }
        let stillHeld = Set(coordinator.heldWindows.map(\.id))
        let snapshot = availability.snapshot(of: sets, currentSpaces: spaces)
        let candidates = looked.filter { stillHeld.contains($0.id) && availability.isGone($0, in: snapshot) }
        guard !candidates.isEmpty else { return }
        // The list may be older than a window coming back (un-minimized, shown again): look once more, right now, at the few that seem gone.
        let fresh = availability.snapshot()
        let gone = candidates.filter { availability.isGone($0, in: fresh) }
        guard !gone.isEmpty else { return }
        // Windows are hidden or rearranged while Mission Control or App Exposé is open: they are not closed.
        // Forget the desktops so the first look after it is the one that waits. (Asked only here: it costs a
        // window list, and nearly every look finds nothing gone.)
        if screens.isMissionControlActive { lastSpaces = []; return }
        gone.forEach { coordinator.release(window: $0.id) }
    }
}
