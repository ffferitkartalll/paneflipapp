import CoreGraphics

/// Where the pointer goes when it is pushed against the edge of a display, with the displays as they stand on the desk: the system's arrangement of them is a
/// staircase and only lets the pointer through where the displays touch in it.
public struct DeskPointer {
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

    private let displays: [Display]

    public init(displays: [Display]) { self.displays = displays }

    /// The place on the display beside the one the pointer is at, on the desk, if the pointer lies against an edge of its display and `delta` pushes it
    /// outward there and a display lies against that edge on the desk at the pointer's height (or width); nil otherwise.
    public func target(from point: CGPoint, delta: CGVector, edge: CGFloat = 1.5) -> CGPoint? {
        guard let from = displays.first(where: { $0.frame.insetBy(dx: -edge, dy: -edge).contains(point) }),
              from.frame.width > 0, from.frame.height > 0 else { return nil }
        let right = delta.dx > 0 && point.x >= from.frame.maxX - edge
        let left = delta.dx < 0 && point.x <= from.frame.minX + edge
        let down = delta.dy > 0 && point.y >= from.frame.maxY - edge
        let up = delta.dy < 0 && point.y <= from.frame.minY + edge
        let horizontal = right || left, vertical = down || up
        guard horizontal || vertical else { return nil }
        // Pushed into a corner: the stronger of the two.
        let alongX = horizontal && (!vertical || abs(delta.dx) >= abs(delta.dy))
        let sx = from.desk.width / from.frame.width, sy = from.desk.height / from.frame.height
        let onDesk = CGPoint(x: from.desk.minX + (point.x - from.frame.minX) * sx, y: from.desk.minY + (point.y - from.frame.minY) * sy)
        let flush: CGFloat = 1
        for to in displays where to.id != from.id && to.desk.width > 0 && to.desk.height > 0 {
            let tx = to.frame.width / to.desk.width, ty = to.frame.height / to.desk.height
            if alongX {
                guard abs((right ? to.desk.minX - from.desk.maxX : from.desk.minX - to.desk.maxX)) <= flush,
                      onDesk.y >= to.desk.minY, onDesk.y <= to.desk.maxY else { continue }
                return CGPoint(x: right ? to.frame.minX + 1 : to.frame.maxX - 2, y: to.frame.minY + (onDesk.y - to.desk.minY) * ty)
            } else {
                guard abs((down ? to.desk.minY - from.desk.maxY : from.desk.minY - to.desk.maxY)) <= flush,
                      onDesk.x >= to.desk.minX, onDesk.x <= to.desk.maxX else { continue }
                return CGPoint(x: to.frame.minX + (onDesk.x - to.desk.minX) * tx, y: down ? to.frame.minY + 1 : to.frame.maxY - 2)
            }
        }
        return nil
    }
}
