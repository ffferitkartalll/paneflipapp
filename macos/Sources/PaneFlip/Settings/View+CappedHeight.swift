import SwiftUI

extension View {
    /// The view at its natural height, or at `cap` when that is more, and then it scrolls: a tab that is taller than the screen does not
    /// make the window taller than the screen. `natural` keeps what was measured, so that the tab is laid out the same way when it is
    /// shown again.
    func cappedHeight(_ cap: CGFloat, natural: Binding<CGFloat>) -> some View {
        modifier(CappedHeight(cap: cap, natural: natural))
    }
}
