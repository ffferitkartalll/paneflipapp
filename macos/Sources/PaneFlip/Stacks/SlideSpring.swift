import CoreGraphics
import SwiftUI

/// The one spring a switch of a zone's windows moves with: the pictures that slide (`PanelSlideStage`) and what shows the switch beside them, the lit card of the
/// grown notch, so that they keep exactly in step. It starts quickly and lands softly, without the long standstill at the end of an ease-in-out
/// curve; critically damped, with no overshoot.
enum SlideSpring {
    static let stiffness: CGFloat = 320
    static let damping: CGFloat = 36
    static let animation = Animation.interpolatingSpring(mass: 1, stiffness: stiffness, damping: damping)
}
