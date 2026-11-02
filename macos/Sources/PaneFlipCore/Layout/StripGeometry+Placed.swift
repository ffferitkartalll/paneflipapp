import CoreGraphics
import Foundation

extension StripGeometry {
    public struct Placed: Equatable {
        public let id: UUID
        public let rect: CGRect
        public let isOnScreen: Bool
    }
}
