import Foundation

public struct NamedLayout: Codable, Identifiable, Equatable {
    public var id: UUID
    public var name: String
    public var root: LayoutNode
    /// Where apps go whose own zone is gone (a display was unplugged): one of this layout's zones, or the first.
    public var defaultZoneID: UUID?
    /// Zones beyond the left and right edges of the screen, reached by scrolling.
    public var leading: [Overflow]
    public var trailing: [Overflow]
    /// The gap between its zones; nil takes the one of the settings.
    public var gap: Double?
    /// The names the user gave to zones, by zone; a zone without one is told by its number.
    public var zoneNames: [UUID: String] = [:]
    /// The zone that floats over the middle of one of the screen's zones, if the user added one.
    public var floating: FloatingZone?
    /// The apps (bundle identifiers) the user ticked to be started together. Only the user changes it.
    public var startApps: Set<String> = []

    public init(id: UUID = UUID(), name: String, root: LayoutNode, defaultZoneID: UUID? = nil,
                leading: [Overflow] = [], trailing: [Overflow] = [], gap: Double? = nil) {
        self.id = id
        self.name = name
        self.root = root
        self.defaultZoneID = defaultZoneID
        self.leading = leading
        self.trailing = trailing
        self.gap = gap
    }

    /// A copy whose zones and dividers have identities of their own, so the apps and edits of the two stay apart.
    public func copy(named name: String) -> NamedLayout {
        var ids: [UUID: UUID] = [:]
        var copy = NamedLayout(name: name, root: root.renewed(&ids), defaultZoneID: defaultZoneID.flatMap { ids[$0] })
        copy.leading = leading.map { Overflow(width: $0.width, root: $0.root.renewed(&ids)) }
        copy.trailing = trailing.map { Overflow(width: $0.width, root: $0.root.renewed(&ids)) }
        copy.gap = gap
        copy.floating = floating.flatMap { float in ids[float.host].map { FloatingZone(host: $0, scale: float.scale) } }
        copy.zoneNames = Dictionary(uniqueKeysWithValues: zoneNames.compactMap { zone, name in ids[zone].map { ($0, name) } })
        return copy
    }

    private static func areas(_ c: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys) throws -> [Overflow] {
        if let list = try? c.decodeIfPresent([Overflow].self, forKey: key) { return list }
        return try c.decodeIfPresent(Overflow.self, forKey: key).map { [$0] } ?? []
    }

    enum CodingKeys: String, CodingKey { case id, name, root, defaultZoneID, leading, trailing, gap, startApps, zoneNames, floating }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        root = try c.decode(LayoutNode.self, forKey: .root)
        // Files written before layouts had a default zone have no such key.
        defaultZoneID = try c.decodeIfPresent(UUID.self, forKey: .defaultZoneID)
        // Files from before a side could hold several areas have one area, not a list.
        leading = try Self.areas(c, .leading)
        trailing = try Self.areas(c, .trailing)
        gap = try c.decodeIfPresent(Double.self, forKey: .gap)
        startApps = try c.decodeIfPresent(Set<String>.self, forKey: .startApps) ?? []
        zoneNames = try c.decodeIfPresent([UUID: String].self, forKey: .zoneNames) ?? [:]
        floating = try c.decodeIfPresent(FloatingZone.self, forKey: .floating)
    }

    /// The screen's layout with the areas beyond its edges.
    public var strip: StripLayout {
        get { StripLayout(leading: leading, root: root, trailing: trailing) }
        set { leading = newValue.leading; root = newValue.root; trailing = newValue.trailing }
    }

    /// Every zone of the layout: those of the screen and beyond its edges, and the floating one.
    public var zoneIDs: [UUID] { strip.zoneIDs + (floatingZone.map { [$0.id] } ?? []) }

    /// The floating zone while the zone it floats over is one of the screen's own (it goes with its host).
    public var floatingZone: FloatingZone? { floating.flatMap { root.leafIDs.contains($0.host) ? $0 : nil } }

    /// The zone that receives apps whose zone is gone: the chosen one while it still exists, else the first.
    public var fallbackZoneID: UUID? {
        let zones = root.leafIDs
        return defaultZoneID.flatMap { zones.contains($0) ? $0 : nil } ?? zones.first
    }
}
