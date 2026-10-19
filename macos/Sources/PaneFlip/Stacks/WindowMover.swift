import CoreGraphics
import Foundation

/// Moves many windows without making the caller wait. A window call waits for the other app, so the moves are made off the
/// main thread, one app at a time (an app is never asked twice at once), and only the latest wanted place of a window is
/// written.
final class WindowMover {
    private let windows: WindowSystem
    private let background: (@escaping () -> Void) -> Void
    private let lock = NSLock()
    private var wanted: [pid_t: [CGWindowID: (ref: WindowRef, point: CGPoint)]] = [:]
    private var writing: Set<pid_t> = []
    /// The place each window was last asked to go to (a window asked for the same place again is not written again).
    private var last: [CGWindowID: CGPoint] = [:]
    private let idle = DispatchGroup()

    init(windows: WindowSystem, background: @escaping (@escaping () -> Void) -> Void) {
        self.windows = windows
        self.background = background
    }

    func move(_ ref: WindowRef, to target: CGPoint) {
        let point = CGPoint(x: target.x.rounded(), y: target.y.rounded())
        lock.lock()
        guard last[ref.id] != point else { lock.unlock(); return }
        last[ref.id] = point
        wanted[ref.pid, default: [:]][ref.id] = (ref, point)
        let start = writing.insert(ref.pid).inserted
        lock.unlock()
        guard start else { return }
        idle.enter()
        background { [self] in write(for: ref.pid) }
    }

    /// Calls `then` on the main thread once every place asked for has been written (so nothing lands after the caller has worked
    /// out the zones), or after a second if an app does not answer. The main thread is never held up.
    func flush(then: @escaping () -> Void) {
        var done = false
        let finish = { [self] in
            guard !done else { return }
            done = true
            lock.lock()
            last = [:]
            lock.unlock()
            then()
        }
        idle.notify(queue: .main, execute: finish)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: finish)
    }

    private func write(for pid: pid_t) {
        while true {
            lock.lock()
            guard let batch = wanted[pid], !batch.isEmpty else {
                writing.remove(pid)
                lock.unlock()
                break
            }
            wanted[pid] = [:]
            lock.unlock()
            for item in batch.values { windows.setPosition(item.point, of: item.ref) }
        }
        idle.leave()
    }
}
