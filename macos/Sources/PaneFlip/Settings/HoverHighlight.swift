import SwiftUI

/// Lights up whatever can be clicked while the pointer is on it, like the island's buttons do. A disabled control stays as it is.
struct HoverHighlight: ViewModifier {
    let radius: CGFloat
    @State private var hovered = false
    @Environment(\.isEnabled) private var enabled

    func body(content: Content) -> some View {
        content
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous).fill(.primary.opacity(hovered && enabled ? 0.1 : 0)).allowsHitTesting(false)
            }
            .onHover { hovered = $0 }
            .animation(.easeOut(duration: 0.1), value: hovered)
    }
}
