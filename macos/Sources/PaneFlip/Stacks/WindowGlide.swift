import CoreGraphics
import Foundation

/// Moves a real window from where it is to its place in a zone over a short time, instead of in one jump.
/// The steps follow the clock, not a count: an app that answers slowly gets fewer steps, never a longer glide, and
/// the last step is always the exact target.
final class WindowGlide {
    private let windows: WindowSystem
    private let reduceMotion: () -> Bool
    /// The steps are window calls that wait for the other app; they must not run on the main thread.
    private let background: (@escaping () -> Void) -> Void
    private let now: () -> TimeInterval
    private let duration: TimeInterval

    private let lock = NSLock()
    private var running: [CGWindowID: Int] = [:]
    private var count = 0

    init(windows: WindowSystem, reduceMotion: @escaping () -> Bool, background: @escaping (@escaping () -> Void) -> Void,
         now: @escaping () -> TimeInterval = { CFAbsoluteTimeGetCurrent() }, duration: TimeInterval = 0.22) {
        self.windows = windows
        self.reduceMotion = reduceMotion
        self.background = background
        self.now = now
        self.duration = duration
    }

    func glide(_ ref: WindowRef, to target: CGRect) {
        guard !reduceMotion(), let start = windows.frame(of: ref), start != target else { return windows.setFrame(target, of: ref) }
        lock.lock()
        count += 1
        let mine = count
        running[ref.id] = mine
        lock.unlock()
        background { [self] in
            let begin = now()
            while isCurrent(mine, for: ref.id) {
                let progress = min((now() - begin) / duration, 1)
                windows.setFrame(progress >= 1 ? target : Self.frame(from: start, to: target, progress: progress), of: ref)
                if progress >= 1 { return finish(mine, for: ref.id) }
            }
        }
    }

    /// The window is no longer ours to place (it left the zone, or the zone changed): stop where it is.
    func cancel(_ id: CGWindowID) {
        lock.lock()
        running[id] = nil
        lock.unlock()
    }

    private func isCurrent(_ token: Int, for id: CGWindowID) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return running[id] == token
    }

    private func finish(_ token: Int, for id: CGWindowID) {
        lock.lock()
        if running[id] == token { running[id] = nil }
        lock.unlock()
    }

    /// Ease-out: fast at first, landing softly.
    private static func frame(from a: CGRect, to b: CGRect, progress: Double) -> CGRect {
        let t = 1 - pow(1 - progress, 3)
        func mix(_ x: CGFloat, _ y: CGFloat) -> CGFloat { x + (y - x) * t }
        return CGRect(x: mix(a.minX, b.minX), y: mix(a.minY, b.minY), width: mix(a.width, b.width), height: mix(a.height, b.height))
    }
}
