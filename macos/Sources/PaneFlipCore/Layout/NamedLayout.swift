import Foundation

public struct NamedLayout: Codable, Identifiable, Equatable {
    public var id: UUID
    public var name: String
    public var root: LayoutNode
    /// Where apps go whose own zone is gone (a display was unplugged): one of this layout's zones, or the first.
    public var defaultZoneID: UUID?

    public init(id: UUID = UUID(), name: String, root: LayoutNode, defaultZoneID: UUID? = nil) {
        self.id = id
        self.name = name
        self.root = root
        self.defaultZoneID = defaultZoneID
    }

    enum CodingKeys: String, CodingKey { case id, name, root, defaultZoneID }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        root = try c.decode(LayoutNode.self, forKey: .root)
        // Files written before layouts had a default zone have no such key.
        defaultZoneID = try c.decodeIfPresent(UUID.self, forKey: .defaultZoneID)
    }

    /// The zone that receives apps whose zone is gone: the chosen one while it still exists, else the first.
    public var fallbackZoneID: UUID? {
        let zones = root.leafIDs
        return defaultZoneID.flatMap { zones.contains($0) ? $0 : nil } ?? zones.first
    }
}
