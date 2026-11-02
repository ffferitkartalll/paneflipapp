import SwiftUI

struct CappedHeight: ViewModifier {
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
