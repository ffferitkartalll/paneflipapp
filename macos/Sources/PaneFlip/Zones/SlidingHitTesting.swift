import SwiftUI

/// Takes no pointer while the cards slide (`ZoneWindowsModel.sliding`). The flag is read here, in this small body, so that its change at the end of a slide does not work out the whole
/// grid of the zone again, only this.
struct SlidingHitTesting: ViewModifier {
    let model: ZoneWindowsModel

    func body(content: Content) -> some View { content.allowsHitTesting(!model.sliding) }
}
