import CoreGraphics
import Foundation

/// Decides when pictures of windows are taken ahead of time, and fills the cache with them (it touches nothing else): when a window leaves the focus,
/// and a moment after everything has come to rest. Never while windows are moving, with motion reduced, or without the permission.
final class PictureKeeper {
    /// How long everything must have been still before the pictures are taken.
    static let settleDelay: TimeInterval = 0.5
    /// A window that could not be photographed is left alone for this long.
    static let retryAfter: TimeInterval = 10
    /// A capture that has not answered after this long is given up (its window may belong to a hung app).
    static let giveUpAfter: TimeInterval = 5

    private let coordinator: StackCoordinator
    private let snapshots: WindowSnapshotting
    private let cache: WindowPictureCache
    private let canCapture: () -> Bool
    private let reduceMotion: () -> Bool
    private let now: () -> TimeInterval
    private let after: (TimeInterval, @escaping () -> Void) -> Void
    private var generation = 0
    private var inFlight = false
    private var captures = 0
    private var queue: [WindowRef] = []
    private var failedAt: [CGWindowID: TimeInterval] = [:]
    /// Windows that lost the focus while others moved: photographed at rest.
    private var left: Set<CGWindowID> = []

    init(coordinator: StackCoordinator, snapshots: WindowSnapshotting, cache: WindowPictureCache, canCapture: @escaping () -> Bool,
         reduceMotion: @escaping () -> Bool, now: @escaping () -> TimeInterval,
         after: @escaping (TimeInterval, @escaping () -> Void) -> Void = { DispatchQueue.main.asyncAfter(deadline: .now() + $0, execute: $1) }) {
        self.coordinator = coordinator
        self.snapshots = snapshots
        self.cache = cache
        self.canCapture = canCapture
        self.reduceMotion = reduceMotion
        self.now = now
        self.after = after
    }

    /// The focus left a window: its picture is what the user last saw. Only a window that shares its zone is ever slid.
    func windowLeftFocus(_ id: CGWindowID) {
        guard let stack = coordinator.stack(containing: id), stack.tabs.count >= 2 else { return }
        cache.forget(id)   // what the user last saw is the next picture, however young the old one is
        left.insert(id)
        if !coordinator.isMoving { motionEnded() }
    }

    /// Something that moved windows is over (or the app has just started): look again once it has been still for a moment.
    func motionEnded() {
        generation += 1
        let mine = generation
        after(Self.settleDelay) { [weak self] in
            guard let self, generation == mine else { return }
            if coordinator.isMoving { return motionEnded() }
            settled()
        }
    }

    private func settled() {
        guard canCapture() else { return }
        guard !reduceMotion() else { return cache.removeAll() }
        let held = Set(coordinator.heldWindows.map(\.id))
        cache.prune(keeping: held)
        let at = now()
        var wanted: [WindowRef] = []
        for stack in coordinator.stacks.values where stack.tabs.count >= 2 && !stack.isParked {
                        // A window in front is live and photographed when it leaves the front (`windowLeftFocus`); a slide takes it fresh anyway.
            for id in stack.tabs.map(\.id) where id != stack.activeID && id != stack.shownID {
                guard let ref = stack.refs[id], !cache.isFresh(id, zoneSize: stack.rect.size), failedAt[id].map({ at - $0 >= Self.retryAfter }) ?? true else { continue }
                wanted.append(ref)
            }
        }
        let leftFirst = wanted.filter { left.contains($0.id) } + wanted.filter { !left.contains($0.id) }
        left = []
        queue = leftFirst
        pump()
    }

    /// One capture at a time; whatever is queued is dropped the moment windows start to move.
    private func pump() {
        guard !inFlight, canCapture(), !coordinator.isMoving, !reduceMotion(), !queue.isEmpty else { return }
        let ref = queue.removeFirst()
        inFlight = true
        captures += 1
        let mine = captures
        after(Self.giveUpAfter) { [weak self] in
            guard let self, inFlight, captures == mine else { return }
            inFlight = false
            failedAt[ref.id] = now()
            pump()
        }
        snapshots.snapshots(of: [ref]) { [weak self] pictures in
            guard let self, captures == mine, inFlight else { return }
            inFlight = false
            if let picture = pictures[ref.id], coordinator.stack(containing: ref.id) != nil {
                cache.store(picture, of: ref.id)
                // A window that cannot fill its zone never passes the size test: do not photograph it again at every rest.
                if !cache.isFresh(ref.id, zoneSize: coordinator.stack(containing: ref.id)?.rect.size) { failedAt[ref.id] = now() }
            } else {
                failedAt[ref.id] = now()
            }
            pump()
        }
    }
}
