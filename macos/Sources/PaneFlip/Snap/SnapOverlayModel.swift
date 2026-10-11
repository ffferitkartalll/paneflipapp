import Foundation
import Observation

/// What the zone overlay shows: the zones (in Cocoa coordinates) and which one is under the pointer.
@Observable
final class SnapOverlayModel {
    struct Zone: Identifiable {
        let id: UUID
        let cocoaRect: CGRect
    }

    var zones: [Zone] = []
    var hoverID: UUID?
}
