import CoreGraphics

/// Whether the displays are arranged as a staircase going up to the right: each display wholly above the one before it, so that the space
/// beside a display, where the zones beyond its edge are kept, is empty and no window parked there is seen on another display.
public struct DisplayStairs: Equatable {
    /// The displays from left to right (the lower one first when they stand at the same place).
    public let order: [String]
    /// `steps[i]` is how `order[i + 1]` lies against `order[i]`.
    public let steps: [StairStep]

    public var isStaircase: Bool { steps.allSatisfy { $0 == .up } }

    /// `frames` are in bottom-left-origin (Cocoa) coordinates, where up is larger y.
    public init(_ frames: [(id: String, frame: CGRect)]) {
        let sorted = frames.sorted { ($0.frame.minX, $0.frame.minY) < ($1.frame.minX, $1.frame.minY) }
        order = sorted.map(\.id)
        steps = zip(sorted, sorted.dropFirst()).map { before, next in
            if next.frame.minY >= before.frame.maxY { return .up }
            if next.frame.maxY <= before.frame.minY { return .down }
            return .level
        }
    }
}
