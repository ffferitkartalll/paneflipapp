import Foundation
import Observation

/// What the zone overlay shows: the zones (in Cocoa coordinates) and which one is under the pointer.
@Observable
final class SnapOverlayModel {

    var zones: [Zone] = []
    var hoverID: UUID?
}
