import SwiftUI
import PaneFlipCore

/// Right-button drag on the pill: carry a segment to a new position and remember the order.
final class PillReorderController {
    private let coordinator: StackCoordinator
    private let settings: AppSettings

    init(coordinator: StackCoordinator, settings: AppSettings) {
        self.coordinator = coordinator
        self.settings = settings
    }

    func handle(_ phase: RightMousePhase, windowX: CGFloat, in stack: ZoneStack) {
        let content = settings.pillContent
        let x = windowX - PillMetrics.padding
        switch phase {
        case .down: pickUp(at: x, in: stack, content: content)
        case .drag: carry(to: x, in: stack, content: content)
        case .up: drop(stack)
        }
    }

    private func pickUp(at x: CGFloat, in stack: ZoneStack, content: PillContent) {
        guard let i = PillMetrics.index(at: x, tabs: stack.tabs, content: content) else { return }
        stack.reorderingID = stack.tabs[i].id
        stack.grabOffset = x - PillMetrics.left(of: i, tabs: stack.tabs, content: content)
        stack.pointerX = x
        stack.interacting = true
    }

    private func carry(to x: CGFloat, in stack: ZoneStack, content: PillContent) {
        guard let id = stack.reorderingID, var i = stack.tabs.firstIndex(where: { $0.id == id }) else { return }
        stack.pointerX = x
        let centre = x - stack.grabOffset + PillMetrics.itemWidth(stack.tabs[i], content) / 2
        func middle(of j: Int) -> CGFloat {
            PillMetrics.left(of: j, tabs: stack.tabs, content: content) + PillMetrics.itemWidth(stack.tabs[j], content) / 2
        }
        // Step over each neighbour whose middle the carried segment has passed.
        while i < stack.tabs.count - 1 && centre > middle(of: i + 1) {
            withAnimation(.smooth(duration: 0.2)) { stack.tabs.swapAt(i, i + 1) }
            i += 1
        }
        while i > 0 && centre < middle(of: i - 1) {
            withAnimation(.smooth(duration: 0.2)) { stack.tabs.swapAt(i, i - 1) }
            i -= 1
        }
    }

    private func drop(_ stack: ZoneStack) {
        guard stack.reorderingID != nil else { return }
        coordinator.persistOrder(of: stack)
        withAnimation(.smooth(duration: 0.2)) { stack.reorderingID = nil }
        stack.interacting = false
    }
}
