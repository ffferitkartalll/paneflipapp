import Foundation

/// The width-to-height ratio a zone keeps in the layout editor, as people name it (16:9).
public struct ZoneAspect: Codable, Hashable {
    public let width: Int
    public let height: Int

    public init(_ width: Int, _ height: Int) {
        self.width = width
        self.height = height
    }

    /// Width divided by height.
    public var value: Double { Double(width) / Double(height) }

    /// The common ones: squarish and wide screens, then the same standing up.
    public static let common: [ZoneAspect] = [
        ZoneAspect(1, 1), ZoneAspect(4, 3), ZoneAspect(3, 2), ZoneAspect(16, 10), ZoneAspect(16, 9), ZoneAspect(21, 9),
        ZoneAspect(3, 4), ZoneAspect(2, 3), ZoneAspect(10, 16), ZoneAspect(9, 16), ZoneAspect(9, 21),
    ]
}
