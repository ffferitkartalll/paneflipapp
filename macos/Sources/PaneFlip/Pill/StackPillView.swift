import PaneFlipCore
import SwiftUI

/// A segmented control in the style of a toolbar filter: a glass capsule with a sliding selection pill,
/// one segment per stacked window. Press and slide to scrub through the windows.
struct StackPillView: View {
    let stack: ZoneStack
    let settings: AppSettings
    let select: (CGWindowID) -> Void

    @State private var hovered: CGWindowID?
    @State private var scrubbing = false
    @Namespace private var selection

    var body: some View {
        let content = settings.pillContent
        HStack(spacing: PillMetrics.spacing) {
            ForEach(Array(stack.tabs.enumerated()), id: \.element.id) { index, tab in
                segment(tab, content: content, index: index)
            }
        }
        .gesture(DragGesture(minimumDistance: 0).onChanged { v in
            if !scrubbing { scrubbing = true; stack.interacting = true }
            if let i = PillMetrics.index(at: v.location.x, tabs: stack.tabs, content: content), stack.tabs[i].id != stack.activeID {
                withAnimation(.smooth(duration: 0.25)) { select(stack.tabs[i].id) }
            }
        }.onEnded { _ in
            scrubbing = false
            stack.interacting = false
        })
        .padding(PillMetrics.padding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func segment(_ tab: ZoneStack.Tab, content: PillContent, index: Int) -> some View {
        let active = tab.id == stack.activeID
        let carried = tab.id == stack.reorderingID
        let delta = carried
            ? (stack.pointerX - stack.grabOffset) - PillMetrics.left(of: index, tabs: stack.tabs, content: content) : 0
        return ZStack {
            if active {
                Capsule().fill(.white.opacity(scrubbing ? 0.32 : 0.2))
                    .overlay(Capsule().strokeBorder(.white.opacity(0.25), lineWidth: 0.5))
                    .matchedGeometryEffect(id: "selection", in: selection)
                    .shadow(color: .black.opacity(scrubbing ? 0.35 : 0), radius: 8, y: 3)
                    .scaleEffect(scrubbing ? 1.1 : 1)
            } else if carried {
                Capsule().fill(.white.opacity(0.22)).shadow(color: .black.opacity(0.35), radius: 8, y: 3)
            } else if tab.id == hovered {
                Capsule().fill(.white.opacity(0.08))
            }
            label(tab, content: content)
        }
        .frame(width: PillMetrics.itemWidth(tab, content), height: PillMetrics.itemHeight)
        .contentShape(.capsule)
        .scaleEffect(carried ? 1.08 : 1)
        .offset(x: delta)
        .zIndex(carried ? 1 : 0)
        .animation(.spring(duration: 0.3, bounce: 0.35), value: scrubbing)
        .onHover { hovered = $0 ? tab.id : nil }
        .help(tab.title)
    }

    private func label(_ tab: ZoneStack.Tab, content: PillContent) -> some View {
        HStack(spacing: 6) {
            if content != .name {
                Group {
                    if let icon = tab.icon { Image(nsImage: icon).resizable() }
                    else { Image(systemName: "macwindow").resizable().scaledToFit() }
                }
                .frame(width: PillMetrics.iconSize, height: PillMetrics.iconSize)
            }
            if content != .icon {
                Text(tab.displayName).font(.system(size: 13, weight: .medium)).lineLimit(1).truncationMode(.tail)
            }
        }
        .padding(.horizontal, content == .icon ? 0 : PillMetrics.textInset)
    }
}
