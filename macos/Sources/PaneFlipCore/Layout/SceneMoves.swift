import CoreGraphics
import Foundation

/// Where the windows of a display go when it is unplugged and the scene says nothing: the default zone goes to the default zone of the target, every other zone to
/// another zone of the target: the nearest one on its screen, else (the target's screen has only its default zone) one beyond its edges, on the side the zone lay on.
public enum SceneMoves {
    private static let area = CGRect(x: 0, y: 0, width: 1000, height: 1000)

    public static func automatic(from source: NamedLayout, to target: NamedLayout) -> [UUID: UUID] {
        let home = target.fallbackZoneID
        let others = target.root.zones(in: area).filter { $0.id != home }
        let sourceRects = Dictionary(uniqueKeysWithValues: source.root.zones(in: area).map { ($0.id, $0.rect) })
        let sourceOrder = source.strip.zoneIDs
        let sourceHome = sourceOrder.firstIndex(of: source.fallbackZoneID ?? UUID())
        // The zones beyond the target's edges, those to the left of its screen and those to the right, each nearest the screen last or first.
        let targetOrder = target.strip.zoneIDs
        let onScreen = Set(target.root.leafIDs)
        let homeIndex = home.flatMap { targetOrder.firstIndex(of: $0) } ?? 0
        let beyond = targetOrder.enumerated().filter { !onScreen.contains($0.element) }
        let beyondLeft = beyond.filter { $0.offset < homeIndex }.map(\.element), beyondRight = beyond.filter { $0.offset > homeIndex }.map(\.element)
        var map: [UUID: UUID] = [:]
        for (index, zone) in sourceOrder.enumerated() {
            if zone == source.fallbackZoneID {
                map[zone] = home
            } else if let rect = sourceRects[zone], let nearest = others.min(by: { distance($0.rect, rect) < distance($1.rect, rect) }) {
                map[zone] = nearest.id
            } else {
                let toTheLeft = index < (sourceHome ?? 0)
                let near = toTheLeft ? (beyondLeft.last ?? beyondRight.first) : (beyondRight.first ?? beyondLeft.last)
                map[zone] = near ?? home
            }
        }
        return map
    }

    /// The same for several remaining displays, by where everything stands on the desk (frames in the desk's units, see `DeskArrangement`). The displays are tried nearest
    /// first (`order`, indices of `targets`: the nearest to the unplugged display's place on the desk first). The default zone goes to the default zone of the nearest one;
    /// every other on-screen zone to the zone nearest to it on the desk, of any remaining display (the default zone of the nearest one is kept for the default zone, the
    /// default zones of the others are zones like the rest); what has no such zone (a zone beyond the edges, or no zone to go to) is placed by the single-display rule
    /// on the nearest display. A zone gets the display (an index of `targets`) and the zone of it.
    public static func onDesk(from source: (frame: CGRect, layout: NamedLayout), onto targets: [(frame: CGRect, layout: NamedLayout)])
        -> (order: [Int], zones: [UUID: (target: Int, zone: UUID)]) {
        guard !targets.isEmpty else { return ([], [:]) }
        let order = targets.indices.sorted { a, b in
            let (ka, kb) = (key(source.frame, targets[a].frame), key(source.frame, targets[b].frame))
            return (ka.gap, ka.middles, a) < (kb.gap, kb.middles, b)
        }
        let nearest = order[0]
        var candidates: [(target: Int, zone: UUID, middle: CGPoint)] = []
        for (index, target) in targets.enumerated() {
            for zone in target.layout.root.zones(in: area) where index != nearest || zone.id != target.layout.fallbackZoneID {
                let rect = DeskArrangement.map(zone.rect, from: area, to: target.frame)
                candidates.append((index, zone.id, CGPoint(x: rect.midX, y: rect.midY)))
            }
        }
        let single = automatic(from: source.layout, to: targets[nearest].layout)
        let rects = Dictionary(uniqueKeysWithValues: source.layout.root.zones(in: area).map { ($0.id, DeskArrangement.map($0.rect, from: area, to: source.frame)) })
        var zones: [UUID: (target: Int, zone: UUID)] = [:]
        for zone in source.layout.strip.zoneIDs {
            if zone != source.layout.fallbackZoneID, let rect = rects[zone],
               let best = candidates.min(by: { distance($0.middle, CGPoint(x: rect.midX, y: rect.midY)) < distance($1.middle, CGPoint(x: rect.midX, y: rect.midY)) }) {
                zones[zone] = (best.target, best.zone)
            } else if let placed = single[zone] {
                zones[zone] = (nearest, placed)
            }
        }
        return (order, zones)
    }

    /// How far apart two frames stand (the gap between them, 0 when they touch), then how far apart their middles.
    private static func key(_ a: CGRect, _ b: CGRect) -> (gap: CGFloat, middles: CGFloat) {
        let gap = distance(CGPoint(x: max(b.minX - a.maxX, a.minX - b.maxX, 0), y: max(b.minY - a.maxY, a.minY - b.maxY, 0)), .zero)
        return (gap, distance(CGPoint(x: a.midX, y: a.midY), CGPoint(x: b.midX, y: b.midY)))
    }

    private static func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat { ((a.x - b.x) * (a.x - b.x) + (a.y - b.y) * (a.y - b.y)).squareRoot() }

    private static func distance(_ a: CGRect, _ b: CGRect) -> CGFloat {
        let dx = a.midX - b.midX, dy = a.midY - b.midY
        return dx * dx + dy * dy
    }
}
