import SwiftUI

extension View {
    func hoverHighlight(radius: CGFloat = 6) -> some View { modifier(HoverHighlight(radius: radius)) }
}
