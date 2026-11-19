import SwiftUI

/// The icon of the search bar turns away, small and fading, as another turns in: the transition between the search icon and the button that ends the search.
struct IconSpin: ViewModifier {
    let angle: Double
    let scale: Double
    let opacity: Double

    func body(content: Content) -> some View {
        content.rotationEffect(.degrees(angle)).scaleEffect(scale).opacity(opacity)
    }
}

extension AnyTransition {
    /// The view turns by `angle` degrees as it comes in or goes out. One goes out first, and the other comes in when it has gone: they are never on top of each other.
    static func spin(_ angle: Double, comesIn: Bool) -> AnyTransition {
        AnyTransition.modifier(active: IconSpin(angle: angle, scale: 0.3, opacity: 0), identity: IconSpin(angle: 0, scale: 1, opacity: 1))
            .animation(comesIn ? .easeOut(duration: 0.14).delay(0.12) : .easeIn(duration: 0.12))
    }
}
