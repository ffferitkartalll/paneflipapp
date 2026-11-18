import AppKit
import SwiftUI

/// Behind a view, takes the turns of a mouse wheel made with the pointer over it (no Shift key needed) and gives each notch to `step`, which says whether it used it: one that did
/// not (nothing to scroll) goes on to what lies behind, as it would. A trackpad's scrolling is not a notch and is left to the view.
struct WheelStepCatcher: NSViewRepresentable {
    /// The notch: negative when the wheel turned toward the user. True when it moved something.
    let step: (CGFloat) -> Bool

    func makeNSView(context: Context) -> Catcher { Catcher() }

    func updateNSView(_ view: Catcher, context: Context) { view.step = step }

    static func dismantleNSView(_ view: Catcher, coordinator: ()) { view.stopWatching() }
}
