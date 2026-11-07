import SwiftUI

struct CappedHeight: ViewModifier {
    let cap: CGFloat
    @Binding var natural: CGFloat

    func body(content: Content) -> some View {
        // A scroll view alone would not tell the window how tall it wants to be: it is only used for what is too tall, at a height of its own.
        let tab = content.fixedSize(horizontal: false, vertical: true)
            .background(GeometryReader { Color.clear.preference(key: NaturalHeightKey.self, value: $0.size.height) })
        Group {
            if natural > cap {
                ScrollView { tab }.frame(height: cap)
            } else if natural == 0 {
                // Not measured yet (the tab is shown for the first time): it is cut off at the cap meanwhile, so that the window never grows to the whole tab for the moment
                // the measuring takes, and then stays that tall.
                tab.frame(maxHeight: cap, alignment: .top).clipped()
            } else {
                tab
            }
        }
        .onPreferenceChange(NaturalHeightKey.self) { natural = $0 }
    }
}
