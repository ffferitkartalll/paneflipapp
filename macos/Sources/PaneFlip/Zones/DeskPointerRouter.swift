import AppKit
import Observation
import PaneFlipCore

/// Answers where the pointer goes at the edge of a display, from the displays as they stand on the desk. The plan is made on the main thread (it reads the
/// settings and the displays) and again whenever they change; the answer is given from the pointer tap's own thread, which only reads the plan, so that the
/// pointer is never held up by what the main thread is doing. Without a desk arrangement set for every display, or with PaneFlip switched off, the pointer
/// is left alone.
// shortcut: not checked by the compiler; the plan is only written under `lock`, and everything else is made and read on the main thread.
final class DeskPointerRouter: @unchecked Sendable {
    private let screens: ScreenProviding
    private let arrangement: () -> DeskArrangement
    private let isOn: () -> Bool
    private let lock = NSLock()
    private var plan: DeskPointer?
    private var observer: NSObjectProtocol?

    init(screens: ScreenProviding, arrangement: @escaping () -> DeskArrangement, isOn: @escaping () -> Bool) {
        self.screens = screens
        self.arrangement = arrangement
        self.isOn = isOn
        refresh()
        observer = NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            self?.refresh()
        }
    }

    deinit { observer.map(NotificationCenter.default.removeObserver) }

    /// Main thread: makes the plan again, now and whenever what it was made from changes.
    private func refresh() {
        let made = withObservationTracking {
            isOn() ? makePointer(arrangement()) : nil
        } onChange: { [weak self] in
            DispatchQueue.main.async { self?.refresh() }
        }
        lock.lock()
        plan = made
        lock.unlock()
    }

    /// Any thread.
    func target(from point: CGPoint, delta: CGVector) -> CGPoint? {
        lock.lock()
        let current = plan
        lock.unlock()
        return current?.target(from: point, delta: delta)
    }

    private func makePointer(_ desk: DeskArrangement) -> DeskPointer? {
        let displays = DeskSpace.distinct(screens.screens())
        let sizes = displays.map { (id: $0.displayID, size: $0.deskSize) }
        guard displays.count > 1, desk.isSet(for: sizes) else { return nil }
        let frames = desk.frames(of: sizes)
        return DeskPointer(displays: displays.compactMap { display in
            frames[display.displayID].map { DeskPointer.Display(id: display.displayID, frame: screens.flip(display.cocoaFrame), desk: $0) }
        })
    }
}
