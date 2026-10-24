import CoreGraphics
import Foundation

/// A zone that floats over the middle of another zone of the screen's layout: a smaller rectangle with the same shape as its host,
/// which a window can be dropped in. A layout has at most one.
public struct FloatingZone: Codable, Equatable {
    /// How much of its host's width and height it takes (so of its diagonal): from a quarter to three quarters.
    public static let scaleRange = 0.25...0.75
    public static let defaultScale = 0.5

    /// The zone's own identity: its stack and its remembered apps are kept under it.
    public let id: UUID
    /// The zone of the layout it floats over.
    public var host: UUID
    public private(set) var scale: Double

    public init(id: UUID = UUID(), host: UUID, scale: Double = FloatingZone.defaultScale) {
        self.id = id
        self.host = host
        self.scale = min(max(scale, Self.scaleRange.lowerBound), Self.scaleRange.upperBound)
    }

    /// Where it stands over a host that stands at `hostRect`: the same centre, `scale` of its width and height.
    public func rect(over hostRect: CGRect) -> CGRect {
        let size = CGSize(width: hostRect.width * scale, height: hostRect.height * scale)
        return CGRect(x: hostRect.midX - size.width / 2, y: hostRect.midY - size.height / 2, width: size.width, height: size.height)
    }

    /// `frame` of a window that cannot be resized, held in the middle of the zone it was meant to fill: a window that does not fit stays
    /// in the middle instead of at the zone's top left corner.
    public static func centred(_ size: CGSize, in zone: CGRect) -> CGRect {
        CGRect(x: zone.midX - size.width / 2, y: zone.midY - size.height / 2, width: size.width, height: size.height)
    }
}
