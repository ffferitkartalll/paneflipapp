import SwiftUI

/// The Dock's badge as a notch draws it, as large as `base` wide at a `scale` of 1. The scale is animatable, and the number is drawn at the size it has, not scaled
/// from another: it stays sharp, and moves and grows with the badge as the notch expands.
struct ZoneNotchBadge: View, Animatable {
    let text: String
    let base: CGFloat
    var scale: CGFloat

    var animatableData: CGFloat {
        get { scale }
        set { scale = newValue }
    }

    var body: some View {
        let side = base * scale
        Text(verbatim: text).font(.system(size: side * 0.5, weight: .bold)).foregroundStyle(.white)
            .lineLimit(1).padding(.horizontal, 2 * scale)
            .frame(minWidth: side, minHeight: side, maxHeight: side)
            .background(Capsule().fill(Color.red))
            .fixedSize()
    }
}
