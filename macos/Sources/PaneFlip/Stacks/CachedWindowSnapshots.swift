import CoreGraphics
import Foundation

/// Answers from the cache of pictures taken ahead of time, and photographs only what it lacks. A window in front is live (it changes while
/// it is used), so its picture counts for a few seconds only; the others keep theirs for as long as the cache does.
final class CachedWindowSnapshots: WindowSnapshotting {
    /// How long the picture of a window in front is good: it is the one it had when it left the front (or last came to rest), and a swipe must not wait for a new one.
    static let frontAge: TimeInterval = 10

    private let inner: WindowSnapshotting
    private let cache: WindowPictureCache
    private let zoneSize: (CGWindowID) -> CGSize?
    private let isFront: (CGWindowID) -> Bool
    private let later: (@escaping () -> Void) -> Void

    /// `later` runs the answer of an all-hits request in a turn of its own (callers set state around the call and are not written for an answer inside it).
    init(inner: WindowSnapshotting, cache: WindowPictureCache, zoneSize: @escaping (CGWindowID) -> CGSize?, isFront: @escaping (CGWindowID) -> Bool,
         later: @escaping (@escaping () -> Void) -> Void = { DispatchQueue.main.async(execute: $0) }) {
        self.inner = inner
        self.cache = cache
        self.zoneSize = zoneSize
        self.isFront = isFront
        self.later = later
    }

    func prepare() { inner.prepare() }

    func snapshots(of refs: [WindowRef], completion: @escaping ([CGWindowID: WindowPicture]) -> Void) {
        var hits: [CGWindowID: WindowPicture] = [:], misses: [WindowRef] = []
        for ref in refs {
            let age = isFront(ref.id) ? Self.frontAge : WindowPictureCache.maxAge
            if let picture = cache.picture(of: ref.id, zoneSize: zoneSize(ref.id), maxAge: age) { hits[ref.id] = picture } else { misses.append(ref) }
        }
        guard !misses.isEmpty else { return later { completion(hits) } }
        inner.snapshots(of: misses) { [cache] fresh in
            for (id, picture) in fresh { cache.store(picture, of: id) }
            completion(hits.merging(fresh) { _, new in new })
        }
    }
}
