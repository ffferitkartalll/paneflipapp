import CoreGraphics
import PaneFlipCore
import SwiftUI

/// Keeps the cards of a grid of a zone's windows (`ZoneWindowsModel`) as the zone has them while the grid is open: a window that came, went or was moved, and the
/// pictures of the windows that have none yet. The grid of one zone and the grid of a whole layout keep their cards with it, so that a zone's cards are the same in both.
final class ZoneCardsKeeper {
    private let coordinator: StackCoordinator
    private let source: ZoneCardSource
    private let snapshots: WindowSnapshotting
    /// The windows pictures were asked for already.
    var asked: Set<CGWindowID> = []

    init(coordinator: StackCoordinator, source: ZoneCardSource, snapshots: WindowSnapshotting) {
        self.coordinator = coordinator
        self.source = source
        self.snapshots = snapshots
    }

    /// The cards of `zone` as it has them now, into `model` (`adjust` may change them first: the cards a grid has moved to another zone and the zone does not know yet).
    /// False when the zone has no card left.
    @discardableResult
    func refresh(_ model: ZoneWindowsModel, zone: UUID, animated: Animation? = .smooth(duration: 0.25), adjust: (([IslandWindow]) -> [IslandWindow])? = nil) -> Bool {
        guard let stack = coordinator.stacks[zone] else { return true }
        let now = adjust?(source.allCards(of: zone)) ?? source.allCards(of: zone)
        guard !now.isEmpty else { return false }
        if now != model.cards { withAnimation(animated) { model.cards = now } }
        if model.tracksFocus, !now.contains(where: { $0.id == model.highlighted }) { model.highlighted = now.first(where: \.isActive)?.id ?? now.first?.id }   // its window went
        askForPictures(of: now, in: stack, for: model)
        return true
    }

    /// The pictures of the windows that have none yet (one that came while the grid was open): they come one by one, the card shows the glyph of its app until then.
    private func askForPictures(of cards: [IslandWindow], in stack: ZoneStack, for model: ZoneWindowsModel) {
        let refs = cards.compactMap { card in card.windowID.flatMap { id in asked.contains(id) ? nil : stack.refs[id] } }
        guard !refs.isEmpty else { return }
        refs.forEach { asked.insert($0.id) }
        snapshots.snapshots(of: refs) { [weak model] pictures in
            guard let model else { return }
            withAnimation(.easeOut(duration: 0.15)) {
                for (id, picture) in pictures { model.pictures["w\(id)"] = picture }
            }
        }
    }
}
