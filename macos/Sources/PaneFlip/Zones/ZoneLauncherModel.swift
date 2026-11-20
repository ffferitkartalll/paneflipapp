import AppKit
import Observation
import SwiftUI

/// What the launcher of one zone shows: the apps that were placed in the zone before (when there are any) and every installed app, in alphabetical order.
@Observable
final class ZoneLauncherModel {
    var placed: [LauncherApp] = []
    var all: [LauncherApp] = []
    /// Shown, or on its way out: the launcher fades in and out.
    var visible = false
    @ObservationIgnored var onLaunch: (String) -> Void = { _ in }
    @ObservationIgnored var onAdd: (String) -> Void = { _ in }
    @ObservationIgnored var onRemove: (String) -> Void = { _ in }
    /// The app of the placed ones that is carried, where the pointer is over it (from where it was taken), and the cells the placed apps stood in when it was taken.
    var carried: String?
    var carriedOffset = CGSize.zero
    /// The places the placed apps stand in, together (in the content's space): a carried app stays inside them, so a single row is not left up or down.
    @ObservationIgnored private var area = CGRect.zero
    /// The app that was taken, until it has settled: it keeps its badge, which goes with it.
    var moving: String?
    @ObservationIgnored var frames: [String: CGRect] = [:]
    @ObservationIgnored private var slots: [CGRect] = []
    @ObservationIgnored private var grab = CGPoint.zero
    @ObservationIgnored private var firstIndex = 0

    /// A placed app is taken at `point` (in the placed part's space).
    func carry(_ id: String, at point: CGPoint) {
        guard carried == nil, let from = placed.firstIndex(where: { $0.bundleID == id }) else { return }
        slots = placed.compactMap { frames[$0.bundleID] }
        guard slots.count == placed.count else { return }
        firstIndex = from
        area = slots.reduce(CGRect.null) { $0.union($1) }
        grab = CGPoint(x: point.x - slots[from].minX, y: point.y - slots[from].minY)
        carried = id
        moving = id
    }

    /// The pointer is at `point`: the app follows it, and the others make room by moving to the places it passes (each with a movement).
    func drag(to raw: CGPoint) {
        guard let id = carried, let at = placed.firstIndex(where: { $0.bundleID == id }) else { return }
        let size = slots[at].size
        var point = raw
        if !area.isEmpty {
            point.x = min(max(raw.x, area.minX + grab.x), max(area.minX + grab.x, area.maxX - size.width + grab.x))
            point.y = min(max(raw.y, area.minY + grab.y), max(area.minY + grab.y, area.maxY - size.height + grab.y))
        }
        if let over = slots.firstIndex(where: { $0.contains(point) }), over != at {
            withAnimation(.smooth(duration: 0.25)) { placed.insert(placed.remove(at: at), at: over) }
        }
        let now = placed.firstIndex(where: { $0.bundleID == id }) ?? at
        carriedOffset = CGSize(width: point.x - grab.x - slots[now].minX, height: point.y - grab.y - slots[now].minY)
    }

    /// Let go: the app settles in its place and the order is kept.
    func drop() {
        guard let id = carried else { return }
        let now = placed.firstIndex(where: { $0.bundleID == id }) ?? firstIndex
        withAnimation(.smooth(duration: 0.25)) { carriedOffset = .zero; carried = nil }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in if self?.moving == id { self?.moving = nil } }   // not the badge of an app taken meanwhile
        if now != firstIndex { onMove(id, now - firstIndex) }
    }

    /// An app of the placed ones was dropped: `offset` places later (or earlier when negative) in the stack.
    @ObservationIgnored var onMove: (String, Int) -> Void = { _, _ in }
    /// The app's glyph as the island draws it, made when a tile first asks for it.
    @ObservationIgnored var makeGlyph: (String) -> NSImage = { _ in NSImage() }
    @ObservationIgnored private var glyphs: [String: NSImage] = [:]

    func glyph(of bundleID: String) -> NSImage {
        if let kept = glyphs[bundleID] { return kept }
        let made = makeGlyph(bundleID)
        glyphs[bundleID] = made
        return made
    }
}

