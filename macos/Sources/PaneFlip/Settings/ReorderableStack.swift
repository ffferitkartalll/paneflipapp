import AppKit
import PaneFlipCore
import SwiftUI

/// Rows of known heights that are reordered by a handle: the carried row follows the pointer, the rows it passes
/// move out of its way (animated), and `move` is told the new place when it is let go.
struct ReorderableStack<Item: Identifiable, Row: View>: View {
    let items: [Item]
    let height: (Item) -> CGFloat
    /// A name of the coordinate space, unique among nested stacks.
    let space: String
    let move: (_ from: Int, _ to: Int) -> Void
    @ViewBuilder let row: (_ item: Item, _ isCarried: Bool, _ drag: @escaping (CGFloat) -> Void,
                           _ drop: @escaping () -> Void) -> Row

    @State private var carried: Item.ID?
    @State private var travel: CGFloat = 0

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                let isCarried = carried == item.id
                row(item, isCarried, { carry(item.id, by: $0) }, { drop() })
                    .background(isCarried ? AnyShapeStyle(.regularMaterial) : AnyShapeStyle(.clear), in: .rect(cornerRadius: 8))
                    .shadow(color: .black.opacity(isCarried ? 0.3 : 0), radius: 6, y: 2)
                    .offset(y: offset(of: index))
                    .zIndex(isCarried ? 1 : 0)
                    .animation(isCarried ? nil : .snappy(duration: 0.2), value: target)
            }
        }
        .coordinateSpace(name: space)
    }

    private var heights: [CGFloat] { items.map(height) }
    private var from: Int? { items.firstIndex { $0.id == carried } }

    private func top(_ index: Int) -> CGFloat { heights[..<index].reduce(0, +) }

    /// How far the carried row may travel without leaving the stack.
    private var limited: CGFloat {
        guard let from else { return 0 }
        return ReorderPlace.limited(travel, heights: heights, from: from)
    }

    /// The place the carried row would be dropped in.
    private var target: Int {
        guard let from else { return 0 }
        return ReorderPlace.target(heights: heights, from: from, travel: travel)
    }

    private func offset(of index: Int) -> CGFloat {
        guard let from else { return 0 }
        let h = heights
        if index == from { return limited }
        if from < target, index > from, index <= target { return -h[from] }
        if target < from, index >= target, index < from { return h[from] }
        return 0
    }

    private func carry(_ id: Item.ID, by translation: CGFloat) {
        if carried != id {
            carried = id
            NSCursor.closedHand.push()
        }
        travel = translation
    }

    private func drop() {
        guard let from else { return }
        NSCursor.pop()
        let to = target
        // The row settles into its place; then the order is saved and the rows are built anew.
        let others = heights.enumerated().filter { $0.offset != from }.map(\.element)
        let settled = others[..<to].reduce(0, +) - top(from)
        withAnimation(.snappy(duration: 0.2)) { travel = settled }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            carried = nil
            travel = 0
            if to != from { move(from, to) }
        }
    }
}
