import Foundation

public struct NamedLayout: Codable, Identifiable, Equatable {
    public var id: UUID
    public var name: String
    public var root: LayoutNode
    /// Where apps go whose own zone is gone (a display was unplugged): one of this layout's zones, or the first.
    public var defaultZoneID: UUID?
    /// Zones beyond the left and right edges of the screen, reached by scrolling.
    public var leading: Overflow?
    public var trailing: Overflow?

    public init(id: UUID = UUID(), name: String, root: LayoutNode, defaultZoneID: UUID? = nil,
                leading: Overflow? = nil, trailing: Overflow? = nil) {
        self.id = id
        self.name = name
        self.root = root
        self.defaultZoneID = defaultZoneID
        self.leading = leading
        self.trailing = trailing
    }

    /// A copy whose zones and dividers have identities of their own, so the apps and edits of the two stay apart.
    public func copy(named name: String) -> NamedLayout {
        var ids: [UUID: UUID] = [:]
        var copy = NamedLayout(name: name, root: root.renewed(&ids), defaultZoneID: defaultZoneID.flatMap { ids[$0] })
        copy.leading = leading.map { Overflow(width: $0.width, root: $0.root.renewed(&ids)) }
        copy.trailing = trailing.map { Overflow(width: $0.width, root: $0.root.renewed(&ids)) }
        return copy
    }

    enum CodingKeys: String, CodingKey { case id, name, root, defaultZoneID, leading, trailing }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        root = try c.decode(LayoutNode.self, forKey: .root)
        // Files written before layouts had a default zone have no such key.
        defaultZoneID = try c.decodeIfPresent(UUID.self, forKey: .defaultZoneID)
        leading = try c.decodeIfPresent(Overflow.self, forKey: .leading)
        trailing = try c.decodeIfPresent(Overflow.self, forKey: .trailing)
    }

    /// The screen's layout with the areas beyond its edges.
    public var strip: StripLayout {
        get { StripLayout(leading: leading, root: root, trailing: trailing) }
        set { leading = newValue.leading; root = newValue.root; trailing = newValue.trailing }
    }

    /// The zone that receives apps whose zone is gone: the chosen one while it still exists, else the first.
    public var fallbackZoneID: UUID? {
        let zones = root.leafIDs
        return defaultZoneID.flatMap { zones.contains($0) ? $0 : nil } ?? zones.first
    }
}
