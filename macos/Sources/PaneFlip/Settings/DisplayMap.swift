import PaneFlipCore
import SwiftUI

/// The displays drawn where the system arranges them. Each display after the first is outlined green when it lies a step above the one to its left,
/// orange when it does not.
struct DisplayMap: View {
    let displays: [ScreenInfo]
    let stairs: DisplayStairs

    var body: some View {
        GeometryReader { proxy in
            let bounds = displays.map(\.cocoaFrame).reduce(CGRect.null) { $0.union($1) }
            let scale = bounds.isNull ? 1 : min(proxy.size.width / bounds.width, proxy.size.height / bounds.height)
            let origin = CGPoint(x: (proxy.size.width - bounds.width * scale) / 2, y: (proxy.size.height - bounds.height * scale) / 2)
            ForEach(displays) { display in
                let frame = display.cocoaFrame
                VStack(spacing: 2) {
                    Text(verbatim: display.name).font(.caption.weight(.medium))
                    Text(verbatim: "\(Int(display.size.width))×\(Int(display.size.height))").font(.caption2).foregroundStyle(.secondary)
                }
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(4)
                .frame(width: frame.width * scale, height: frame.height * scale)
                .background(.quaternary, in: .rect(cornerRadius: 4))
                .overlay { RoundedRectangle(cornerRadius: 4).stroke(outline(of: display), lineWidth: 2) }
                .position(x: origin.x + (frame.midX - bounds.minX) * scale, y: origin.y + (bounds.maxY - frame.midY) * scale)
            }
        }
    }

    private func outline(of display: ScreenInfo) -> Color {
        guard let index = stairs.order.firstIndex(of: display.displayID), index > 0 else { return .secondary }
        return stairs.steps[index - 1] == .up ? .green : .orange
    }
}
