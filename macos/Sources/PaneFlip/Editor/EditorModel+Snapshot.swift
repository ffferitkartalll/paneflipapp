import CoreGraphics
import Foundation
import Observation
import PaneFlipCore

extension EditorModel {
    struct Snapshot {
        let strip: StripLayout
        let offset: Double
        let defaultZone: UUID?
        let aspects: [UUID: ZoneAspect]
    }
}
