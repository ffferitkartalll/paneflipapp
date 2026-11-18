import CoreGraphics
import Foundation
import PaneFlipCore

/// The windows a scene change leaves without a zone (the scene now in use does not remember them): each is stacked with a part of each showing in the usable area of its display (less the margin
/// the layout keeps round its edges), behind the windows the default zone of that layout has. They stay in no zone and in no memory.
final class LooseWindows {
    private let windows: WindowSystem
    private let screens: ScreenProviding
    private let repository: LayoutRepository
    private let memory: StackMemory
    private let coordinator: StackCoordinator
    private var waiting: [WindowRef] = []

    init(windows: WindowSystem, screens: ScreenProviding, repository: LayoutRepository, memory: StackMemory, coordinator: StackCoordinator) {
        self.windows = windows
        self.screens = screens
        self.repository = repository
        self.memory = memory
        self.coordinator = coordinator
    }

    /// The windows that left their zones with a scene change, until the windows of the new scene have taken theirs (`settle`). A newer change replaces them.
    func gather(_ refs: [WindowRef]) { waiting = refs }

    /// The windows of the new scene have taken their places: those that are still without one are put behind them.
    func settle() {
        let refs = waiting
        waiting = []
        guard !refs.isEmpty else { return }
        let bound = memory.boundWindowIDs
        let current = screens.screens()
        // The windows of each default zone, in the order they were gathered.
        var byZone: [(stack: ZoneStack, refs: [WindowRef])] = []
        for ref in refs where !bound.contains(ref.id) && !coordinator.pulledOut.contains(ref.id) && !windows.isMinimized(ref) {
            guard let frame = windows.frame(of: ref) else { continue }
            let middle = CGPoint(x: frame.midX, y: frame.midY)
            guard let screen = current.first(where: { $0.axVisible.contains(middle) }) ?? current.first,
                  let zone = repository.activeLayout(for: screen.key)?.fallbackZoneID, let stack = coordinator.stacks[zone], !stack.isParked else { continue }
            if let i = byZone.firstIndex(where: { $0.stack === stack }) { byZone[i].refs.append(ref) } else { byZone.append((stack, [ref])) }
        }
        generation += 1   // a newer change stops the raises of an older one
        let mine = generation
        for (stack, refs) in byZone {
            // The room is the usable area of the display less the margin its layout keeps round the edges (as an enlarged window has), not the zone.
            let margin = coordinator.edgeMarginOf(stack.rect)
            let room = coordinator.usableAreaOf(stack.rect)?.insetBy(dx: margin, dy: margin) ?? stack.frame
            for (ref, frame) in zip(refs, Self.cascade(in: room, count: refs.count)) { windows.setFrame(frame, of: ref) }
            // Back to front, the zone's own front window last, one at a time: the next is not asked for before the one before it stands in front of the windows asked for
            // already (a raise is carried out by the other app, and raises asked at once are not carried out in the order they were asked in).
            var steps: [(id: CGWindowID, raise: () -> Void)] = refs.map { ref in (ref.id, { [windows] in windows.raise(ref) }) }
            if let front = stack.activeID { steps.append((front, { [coordinator] in coordinator.select(front, in: stack) })) }
            raise(steps[...], after: [], generation: mine)
        }
    }

    private var generation = 0
    private static let poll = 0.05, patience = 3.0

    /// Asks for the first of `steps`, waits until it stands in front of `done`, then goes on with the rest. A window that does not come forward within `patience` seconds
    /// (it has gone, or its app does not let it) is passed over, so that the rest does not wait for ever.
    private func raise(_ steps: ArraySlice<(id: CGWindowID, raise: () -> Void)>, after done: [CGWindowID], generation: Int, waited: Double = 0) {
        guard self.generation == generation, let step = steps.first else { return }
        if waited == 0 { step.raise() }
        if Self.stands(step.id, infrontOf: done, in: windows.windowIDsFrontToBack()) || waited >= Self.patience {
            return raise(steps.dropFirst(), after: done + [step.id], generation: generation)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.poll) { [weak self] in
            self?.raise(steps, after: done, generation: generation, waited: waited + Self.poll)
        }
    }

    /// Whether `id` is in front of every window of `others` that is on screen (`frontToBack`: the windows on screen, the frontmost first), and on screen itself.
    static func stands(_ id: CGWindowID, infrontOf others: [CGWindowID], in frontToBack: [CGWindowID]) -> Bool {
        guard let place = frontToBack.firstIndex(of: id) else { return false }
        return others.allSatisfy { other in frontToBack.firstIndex(of: other).map { place < $0 } ?? true }
    }

    /// The frames of `count` windows stacked in `rect` with a part of each showing: the first is at the back in the upper left corner, each next one shifted down and to the right, the last at the
    /// front in the lower right; all as large as what is left of `rect` after the shifts (which are 24 pt at most, and leave each window at least 60% of the room).
    static func cascade(in rect: CGRect, count: Int) -> [CGRect] {
        guard count > 0 else { return [] }
        let step = count > 1 ? min(24, min(rect.width, rect.height) * 0.4 / CGFloat(count - 1)) : 0
        let size = CGSize(width: rect.width - step * CGFloat(count - 1), height: rect.height - step * CGFloat(count - 1))
        return (0..<count).map { i in
            let shift = step * CGFloat(i)
            return CGRect(origin: CGPoint(x: rect.minX + shift, y: rect.minY + shift), size: size)
        }
    }
}
