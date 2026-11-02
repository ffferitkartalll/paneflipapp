import CoreGraphics
import Foundation

extension ZoneGlyph {
    public struct Cell: Identifiable, Equatable {
        public let id: UUID
        /// In the picture, from its top left corner.
        public let rect: CGRect
        /// The zone lies on the screen; else it waits beyond an edge.
        public let isOnScreen: Bool
    }
}
