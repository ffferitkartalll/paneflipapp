import CoreGraphics

extension DeskPointer {
    public struct Display {
        public let id: String
        /// The display in the system's arrangement, in top-left-origin coordinates (the pointer's).
        public let frame: CGRect
        /// The display on the desk.
        public let desk: CGRect

        public init(id: String, frame: CGRect, desk: CGRect) {
            self.id = id
            self.frame = frame
            self.desk = desk
        }
    }
}
