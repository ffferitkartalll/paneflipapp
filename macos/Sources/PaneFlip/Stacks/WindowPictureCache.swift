import Foundation
import CoreGraphics

/// Pictures of windows taken ahead of time, so a slide or scrub can start at once instead of waiting for a capture.
/// Bounded by memory (least recently used goes first), by age, and by the size of the zone the picture must fill. Main thread only.
final class WindowPictureCache {
    private struct Entry {
        let picture: WindowPicture
        let storedAt: TimeInterval
        var usedAt: TimeInterval
        let bytes: Int
    }

    /// A picture older than this is taken again.
    static let maxAge: TimeInterval = 60
    /// How far a picture's size may be from the zone's: more would show a stretched or short window.
    static let sizeTolerance: CGFloat = 1.5

    private let maxBytes: Int
    private let now: () -> TimeInterval
    private var entries: [CGWindowID: Entry] = [:]
    private(set) var totalBytes = 0

    init(maxBytes: Int = 256 << 20, now: @escaping () -> TimeInterval) {
        self.maxBytes = maxBytes
        self.now = now
    }

    var count: Int { entries.count }

    /// The picture of a window if it is young enough and fits `zoneSize` (nil: any size). One that does not is dropped.
    func picture(of id: CGWindowID, zoneSize: CGSize?, maxAge: TimeInterval = WindowPictureCache.maxAge) -> WindowPicture? {
        // Dropped only when it is really out of date or the wrong size; a short `maxAge` (a window in front) just misses.
        guard isFresh(id, zoneSize: zoneSize) else { forget(id); return nil }
        guard isFresh(id, zoneSize: zoneSize, maxAge: maxAge) else { return nil }
        entries[id]?.usedAt = now()
        return entries[id]?.picture
    }

    /// Whether `picture(of:…)` would answer, without using the picture.
    func isFresh(_ id: CGWindowID, zoneSize: CGSize?, maxAge: TimeInterval = WindowPictureCache.maxAge) -> Bool {
        guard let entry = entries[id], now() - entry.storedAt < maxAge else { return false }
        guard let zoneSize else { return true }
        let size = entry.picture.frame.size
        return abs(size.width - zoneSize.width) <= Self.sizeTolerance && abs(size.height - zoneSize.height) <= Self.sizeTolerance
    }

    func store(_ picture: WindowPicture, of id: CGWindowID) {
        forget(id)
        let bytes = picture.image.bytesPerRow * picture.image.height
        guard bytes <= maxBytes else { return }
        let at = now()
        entries[id] = Entry(picture: picture, storedAt: at, usedAt: at, bytes: bytes)
        totalBytes += bytes
        while totalBytes > maxBytes, let oldest = entries.min(by: { $0.value.usedAt < $1.value.usedAt })?.key { forget(oldest) }
    }

    func forget(_ id: CGWindowID) {
        if let entry = entries.removeValue(forKey: id) { totalBytes -= entry.bytes }
    }

    /// Keeps only the pictures of windows that are still held.
    func prune(keeping alive: Set<CGWindowID>) {
        for id in entries.keys where !alive.contains(id) { forget(id) }
    }

    func removeAll() {
        entries = [:]
        totalBytes = 0
    }
}
