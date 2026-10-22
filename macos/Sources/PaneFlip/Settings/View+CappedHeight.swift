import SwiftUI

extension View {
    /// The view at its natural height, or at `cap` when that is more, and then it scrolls: a tab that is taller than the screen does not
    /// make the window taller than the screen. `natural` keeps what was measured, so that the tab is laid out the same way when it is
    /// shown again.
    func cappedHeight(_ cap: CGFloat, natural: Binding<CGFloat>) -> some View {
        modifier(CappedHeight(cap: cap, natural: natural))
    }
}

private struct NaturalHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

private struct CappedHeight: ViewModifier {
    let cap: CGFloat
    @Binding var natural: CGFloat

    func body(content: Content) -> some View {
        // A scroll view alone would not tell the window how tall it wants to be: it is only used for what is too tall, at a height of its own.
        let tab = content.fixedSize(horizontal: false, vertical: true)
            .background(GeometryReader { Color.clear.preference(key: NaturalHeightKey.self, value: $0.size.height) })
        Group {
            if natural > cap { ScrollView { tab }.frame(height: cap) } else { tab }
        }
        .onPreferenceChange(NaturalHeightKey.self) { natural = $0 }
    }
}
