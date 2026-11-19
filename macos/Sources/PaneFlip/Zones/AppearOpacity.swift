import SwiftUI

/// Fades what it is put on with the grid's opening (`ZoneWindowsModel.appear`). The value is read here, in this small body, so that only this is worked out at every step of the
/// slide, not the card it belongs to.
struct AppearOpacity: ViewModifier {
    let model: ZoneWindowsModel

    func body(content: Content) -> some View { content.opacity(model.appear) }
}
