import SwiftUI

extension View {
    /// `action` when the view is clicked with the right mouse button.
    func onRightClick(perform action: @escaping () -> Void) -> some View {
        overlay { RightClickCatcher(action: action) }
    }
}
