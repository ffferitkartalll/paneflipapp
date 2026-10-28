import CoreGraphics
import Foundation

/// Remembers that a window of an app belongs to a zone. Survives the window closing and the app relaunching.
public struct StackRecord: Codable, Equatable {
    public var id: UUID
    public var zoneID: UUID
    public var bundleID: String
    public var title: String
    /// Zones this slot had in other layouts, so it goes back to them when such a layout is active again.
    public var otherZones: [UUID] = []
    /// The zone this slot belongs to while its display is unplugged and its window stands apart, or has been put in a zone of another display: it goes back there when that display returns.
    public var home: UUID?
    /// The live window currently filling this slot, if any. Not persisted: window numbers change on every launch.
    public var windowID: CGWindowID?

    public init(id: UUID = UUID(), zoneID: UUID, bundleID: String, title: String, windowID: CGWindowID? = nil) {
        self.id = id
        self.zoneID = zoneID
        self.bundleID = bundleID
        self.title = title
        self.windowID = windowID
    }

    enum CodingKeys: String, CodingKey { case id, zoneID, bundleID, title, otherZones, home }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        zoneID = try c.decode(UUID.self, forKey: .zoneID)
        bundleID = try c.decode(String.self, forKey: .bundleID)
        title = try c.decode(String.self, forKey: .title)
        // Files written before layouts were remembered per slot have no such key.
        otherZones = try c.decodeIfPresent([UUID].self, forKey: .otherZones) ?? []
        home = try c.decodeIfPresent(UUID.self, forKey: .home)
    }
}
