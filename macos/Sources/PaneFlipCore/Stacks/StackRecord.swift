import CoreGraphics
import Foundation

/// Remembers that a window of an app belongs to a zone. Survives the window closing and the app relaunching.
public struct StackRecord: Codable, Equatable {
    public var id: UUID
    public var zoneID: UUID
    public var bundleID: String
    public var title: String
    /// The live window currently filling this slot, if any. Not persisted: window numbers change on every launch.
    public var windowID: CGWindowID?

    public init(id: UUID = UUID(), zoneID: UUID, bundleID: String, title: String, windowID: CGWindowID? = nil) {
        self.id = id
        self.zoneID = zoneID
        self.bundleID = bundleID
        self.title = title
        self.windowID = windowID
    }

    enum CodingKeys: String, CodingKey { case id, zoneID, bundleID, title }
}
