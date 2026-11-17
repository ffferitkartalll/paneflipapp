import PaneFlipCore
import SwiftUI

/// A layout drawn small, in the shape of the screen it is for; the zones are numbered in tree order. Made from a strip it shows the areas beyond the
/// screen's edges beside the screen (`width` is then the whole picture's), the lines of the screen's own edges dashed.
struct LayoutMiniature: View {
    let root: LayoutNode
    let screenSize: CGSize
    let width: CGFloat
    /// Where the screen's own edges lie, as fractions of the width; empty when there is nothing beyond them.
    var edges: [CGFloat] = []
    /// What each zone is called (-1, 2, +1…) when it is not just its number; made from a strip.
    var labels: [UUID: String] = [:]

    init(root: LayoutNode, screenSize: CGSize, width: CGFloat) {
        self.root = root
        self.screenSize = screenSize
        self.width = width
    }

    init(strip: StripLayout, screenSize: CGSize, width: CGFloat) {
        let total = CGFloat(strip.totalWidth)
        root = strip.composite
        self.screenSize = CGSize(width: screenSize.width * total, height: screenSize.height)
        self.width = width
        labels = Dictionary(uniqueKeysWithValues: strip.zoneIDs.map { ($0, ZoneLabel.text(of: $0, in: strip)) })
        edges = total > 1 ? [CGFloat(strip.leadingWidth) / total, CGFloat(strip.leadingWidth + 1) / total] : []
    }

    @Environment(\.displayScale) private var scale

    /// A position on a whole pixel of the display: a line of the zones between two pixels is drawn blurred or cut at the edge of the picture.
    private func snapped(_ value: CGFloat) -> CGFloat { (value * scale).rounded() / scale }

    private var height: CGFloat { snapped(width * screenSize.height / screenSize.width) }

    var body: some View {
        Canvas { gc, size in
            for (i, z) in root.zones(in: CGRect(origin: .zero, size: size)).enumerated() {
                let box = CGRect(x: snapped(z.rect.minX), y: snapped(z.rect.minY), width: snapped(z.rect.maxX) - snapped(z.rect.minX), height: snapped(z.rect.maxY) - snapped(z.rect.minY))
                // A line is 1 pt wide and lies in whole pixels: 1 pt in from the zone's edge, its middle half a point further. Between two zones there are 2 pt, and at the picture's edge 1 pt, so that no line is cut or blurred (on a display of one pixel to the point too).
                let shape = Path(roundedRect: box.insetBy(dx: 1.5, dy: 1.5), cornerRadius: 3.5)
                gc.stroke(shape, with: .color(.secondary))
                if z.rect.width > 14 && z.rect.height > 14 {
                    gc.draw(Text(verbatim: labels[z.id] ?? "\(i + 1)").font(.caption2).foregroundStyle(.secondary),
                            at: CGPoint(x: z.rect.minX + 9, y: z.rect.minY + 9))
                }
            }
            for edge in edges where edge > 0 && edge < 1 {
                var line = Path()
                line.move(to: CGPoint(x: snapped(size.width * edge) + 0.5, y: 0))
                line.addLine(to: CGPoint(x: snapped(size.width * edge) + 0.5, y: size.height))
                gc.stroke(line, with: .color(.primary.opacity(0.6)), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
            }
        }
        .frame(width: snapped(width), height: height)
        .background(.quaternary, in: .rect(cornerRadius: 8))
    }
}
