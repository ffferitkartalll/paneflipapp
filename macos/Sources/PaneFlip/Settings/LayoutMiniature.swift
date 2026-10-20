import PaneFlipCore
import SwiftUI

/// A layout drawn small, in the shape of the screen it is for; the zones are numbered in tree order.
struct LayoutMiniature: View {
    let root: LayoutNode
    let screenSize: CGSize
    let width: CGFloat

    var body: some View {
        Canvas { gc, size in
            for (i, z) in root.zones(in: CGRect(origin: .zero, size: size)).enumerated() {
                gc.stroke(Path(roundedRect: z.rect.insetBy(dx: 1, dy: 1), cornerRadius: 4), with: .color(.secondary))
                gc.draw(Text(verbatim: "\(i + 1)").font(.caption2).foregroundStyle(.secondary),
                        at: CGPoint(x: z.rect.minX + 9, y: z.rect.minY + 9))
            }
        }
        .aspectRatio(screenSize.width / screenSize.height, contentMode: .fit)
        .frame(width: width)
        .background(.quaternary, in: .rect(cornerRadius: 8))
    }
}
