import CoreGraphics

/// Where the displays stand on the desk, set by the user: the arrangement the system keeps is a staircase (so that no zone beyond a display's edge lands
/// on another display), which says nothing of how the displays really lie. A display's place is the top-left corner of its frame, in points, with y
/// growing downward; its frame has the size of the display.
public struct DeskArrangement: Equatable, Codable {
    public var origins: [String: CGPoint]

    public init(origins: [String: CGPoint] = [:]) { self.origins = origins }

    /// Every one of the displays has a place.
    public func isSet(for displays: [(id: String, size: CGSize)]) -> Bool {
        !displays.isEmpty && displays.allSatisfy { origins[$0.id] != nil }
    }

    /// The frame of each display: the place it was given, and for one without a place (a display just plugged in, or none placed yet) the next free
    /// place in a row to the right of the others, in the order of `displays` (from left to right in the system's arrangement).
    public func frames(of displays: [(id: String, size: CGSize)]) -> [String: CGRect] {
        var frames: [String: CGRect] = [:]
        for display in displays {
            if let origin = origins[display.id] { frames[display.id] = CGRect(origin: origin, size: display.size) }
        }
        var x = frames.values.map(\.maxX).max() ?? 0
        for display in displays where frames[display.id] == nil {
            frames[display.id] = CGRect(origin: CGPoint(x: x, y: 0), size: display.size)
            x += display.size.width
        }
        return frames
    }

    /// A rectangle of a display's screen at the same place on the display's frame on the desk.
    public static func map(_ rect: CGRect, from screen: CGRect, to desk: CGRect) -> CGRect {
        guard screen.width > 0, screen.height > 0 else { return rect }
        let sx = desk.width / screen.width, sy = desk.height / screen.height
        return CGRect(x: desk.minX + (rect.minX - screen.minX) * sx, y: desk.minY + (rect.minY - screen.minY) * sy,
                      width: rect.width * sx, height: rect.height * sy)
    }
}
