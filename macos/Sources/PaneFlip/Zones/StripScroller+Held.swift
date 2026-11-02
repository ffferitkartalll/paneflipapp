import CoreGraphics
import Foundation
import PaneFlipCore

extension StripScroller {
    /// A window of the screen's zones, with where its zone stood when the scroll began.
    struct Held {
        let ref: WindowRef
        let zone: UUID
        let rect: CGRect
        let isFront: Bool
        let isParked: Bool
    }
}
