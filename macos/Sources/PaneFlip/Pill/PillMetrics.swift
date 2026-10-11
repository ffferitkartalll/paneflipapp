import AppKit
import PaneFlipCore

/// The geometry of the stack pill: segment widths, positions and hit-testing. No drawing, no state.
enum PillMetrics {
    /// A standard macOS toolbar height.
    static let height: CGFloat = 52
    static let spacing: CGFloat = 2
    static let padding: CGFloat = 3
    static let itemHeight: CGFloat = height - 2 * padding
    static let iconSize: CGFloat = 32
    static let textInset: CGFloat = 14

    static func itemWidth(_ tab: ZoneStack.Tab, _ content: PillContent) -> CGFloat {
        if content == .icon { return 70 }
        let text = (tab.displayName as NSString)
            .size(withAttributes: [.font: NSFont.systemFont(ofSize: 13, weight: .medium)]).width.rounded(.up)
        let icon = content == .both ? iconSize + 6 : 0
        return min(max(text + icon + 2 * textInset, 70), 240)
    }

    static func width(for tabs: [ZoneStack.Tab], content: PillContent) -> CGFloat {
        tabs.reduce(0) { $0 + itemWidth($1, content) } + CGFloat(max(tabs.count - 1, 0)) * spacing + 2 * padding
    }

    /// Left edge of segment `i`, in coordinates without the outer padding.
    static func left(of i: Int, tabs: [ZoneStack.Tab], content: PillContent) -> CGFloat {
        (0..<i).reduce(0) { $0 + itemWidth(tabs[$1], content) + spacing }
    }

    /// The segment under `x` (clamped to the ends).
    static func index(at x: CGFloat, tabs: [ZoneStack.Tab], content: PillContent) -> Int? {
        guard !tabs.isEmpty else { return nil }
        for i in tabs.indices where x < left(of: i, tabs: tabs, content: content) + itemWidth(tabs[i], content) + spacing / 2 { return i }
        return tabs.count - 1
    }
}
