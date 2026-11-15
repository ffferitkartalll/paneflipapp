import CoreGraphics
import Foundation
import Observation
import PaneFlipCore

/// What the grid of a whole layout shows on one display (`LayoutGridView`): in every zone of the display's layout, those of the screens beyond the edges too, the grid of the
/// zone's windows, exactly as the grid of one zone shows it.
@Observable
final class LayoutGridModel {
    /// The zones in the order of the layout.
    var zones: [LayoutGridZone] = []
    var size: CGSize = .zero
    /// The whole display (the panel's size), and where its usable area, the room of the grid, lies in it.
    var wholeSize: CGSize = .zero
    var inset: CGPoint = .zero
    /// How far the grid has been scrolled toward the screens beyond the right edge since it opened, in points (negative: toward the left), and the places it rests at.
    var shift: CGFloat = 0
    var rests: [CGFloat] = [0]
    /// The card the mouse carries, while the pointer is on this display.
    var carry: LayoutGridGhost?
    /// Where the display's usable area begins, in Accessibility coordinates; and the zone that had the focus when the grid opened.
    @ObservationIgnored var origin: CGPoint = .zero
    @ObservationIgnored var focused: UUID?
    @ObservationIgnored var onClose: () -> Void = {}

    /// Every card with its zone and its place in the room of the display (before the grid is scrolled).
    var places: [LayoutGridPlace] {
        zones.flatMap { zone in zip(zone.model.cards, zone.model.cells).map { LayoutGridPlace(zone: zone, card: $0, rect: $1.offsetBy(dx: zone.rect.minX, dy: zone.rect.minY)) } }
    }

    /// Whether a card is in view on the display now (the middle of it is, the grid scrolled).
    func isInView(_ place: LayoutGridPlace) -> Bool {
        let middle = place.rect.midX - shift
        return middle >= 0 && middle <= size.width
    }

    /// The rest the grid scrolls to, `steps` screens further (to the right: positive); where it is, when there is none that way.
    func rest(steps: Int) -> CGFloat {
        guard steps != 0 else { return shift }
        return (steps > 0 ? rests.sorted().first { $0 > shift + 0.5 } : rests.sorted().last { $0 < shift - 0.5 }) ?? shift
    }

    /// The card to be chosen: where the pointer or the arrow keys are, else the card with the focus. Nil when this display has neither.
    var current: LayoutGridPlace? {
        let all = places
        return all.first { $0.zone.model.pointed == $0.card.id }
            ?? all.first { $0.zone.id == focused && $0.zone.model.highlighted == $0.card.id }
    }

    /// The card to be chosen is this one (nil: none on this display); it is the only one marked.
    func select(_ place: LayoutGridPlace?) {
        zones.forEach { $0.model.pointed = nil }
        place?.zone.model.pointed = place?.card.id
    }

    /// The nearest card of this display toward `direction` from `place`, in its zone or in another one; nil when there is none that way.
    func neighbour(of place: LayoutGridPlace, toward direction: ZoneDirection) -> LayoutGridPlace? {
        let all = places
        guard let current = all.firstIndex(where: { $0.zone.id == place.zone.id && $0.card.id == place.card.id }) else { return nil }
        let others = all.enumerated().map { (id: $0.offset, rect: $0.element.rect, number: $0.offset) }
        return ZoneNeighbour.nearest(to: all[current].rect, number: current, among: others, toward: direction).map { all[$0] }
    }

    /// Where the grid is to be scrolled for `place` to be in view: where it is when it is, else the nearest rest that shows the middle of the card.
    func shiftShowing(_ place: LayoutGridPlace) -> CGFloat {
        let shows = { (rest: CGFloat) in place.rect.midX - rest >= 0 && place.rect.midX - rest <= self.size.width }
        return shows(shift) ? shift : rests.filter(shows).min { abs($0 - shift) < abs($1 - shift) } ?? shift
    }

    /// The zone the pointer is over when it is at `point` (in the room of the display, the grid scrolled): the one it is in, else the nearest one.
    func zone(at point: CGPoint) -> LayoutGridZone? {
        let layer = CGPoint(x: point.x + shift, y: point.y)
        func distance(_ rect: CGRect) -> CGFloat {
            let dx = max(rect.minX - layer.x, 0, layer.x - rect.maxX), dy = max(rect.minY - layer.y, 0, layer.y - rect.maxY)
            return dx * dx + dy * dy
        }
        return zones.min { distance($0.rect) < distance($1.rect) }
    }
}
