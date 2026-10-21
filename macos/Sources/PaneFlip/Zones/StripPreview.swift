import PaneFlipCore
import SwiftUI

/// A small map of a screen's strip: the areas beyond its edges as blocks on either side of the screen, and a frame for the stretch of it that
/// the screen shows now. The layout editor and the scrolling of the layout both show it.
struct StripPreview: View {
    let strip: StripLayout
    /// How far the screen's view has moved to the right of its own place, in screen widths.
    let offset: Double
    /// Text under the map, if any.
    var caption: Text?
    /// Whether the frame slides when the offset changes (the editor's does; while the layout scrolls it follows the pictures frame by frame).
    var animated = false

    /// How wide one screen is in the map, at most, in points, and how wide the whole map may be.
    private static let unit: CGFloat = 56
    private static let widest: CGFloat = 220

    /// The size of the panel that holds the map, for one that shows a strip of this width (without a caption).
    static func size(for strip: StripLayout) -> CGSize {
        let unit = Self.unit(for: strip)
        return CGSize(width: CGFloat(strip.totalWidth) * unit + 28, height: unit * 0.62 + 4 + 20)
    }

    private static func unit(for strip: StripLayout) -> CGFloat { min(unit, widest / CGFloat(strip.totalWidth)) }

    var body: some View {
        let unit = Self.unit(for: strip)
        let height = unit * 0.62
        // The parts from the left: the areas beyond the left edge, the outermost first, then the screen, then the areas on the right.
        let widths = strip.leading.reversed().map(\.width) + [1] + strip.trailing.map(\.width)
        let starts = widths.indices.map { i in widths[..<i].reduce(0, +) }
        VStack(spacing: 8) {
            ZStack(alignment: .topLeading) {
                ForEach(widths.indices, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 4)
                        .fill(i == strip.leading.count ? Color.white.opacity(0.14) : Color.orange.opacity(0.3))
                        .frame(width: max(CGFloat(widths[i]) * unit - 2, 1), height: height)
                        .offset(x: CGFloat(starts[i]) * unit + 1)
                }
                RoundedRectangle(cornerRadius: 5)
                    .strokeBorder(Color.accentColor, lineWidth: 2)
                    .frame(width: unit, height: height + 4)
                    .offset(x: CGFloat(strip.leadingWidth + offset) * unit, y: -2)
                    .animation(animated ? .smooth(duration: 0.4) : nil, value: offset)
            }
            .frame(width: CGFloat(strip.totalWidth) * unit, height: height + 4, alignment: .topLeading)
            if let caption { caption.font(.callout).foregroundStyle(.secondary) }
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .glassEffect(.regular, in: .rect(cornerRadius: 12))
    }
}
