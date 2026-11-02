import Foundation
import Observation

extension SnapOverlayModel {
    struct Zone: Identifiable {
        let id: UUID
        let cocoaRect: CGRect
    }
}
