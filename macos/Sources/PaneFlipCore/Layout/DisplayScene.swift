import Foundation

/// A scene: a set-up of all the displays: the layout each display uses and, for each zone, where its windows go when its display is unplugged.
/// What a scene leaves out follows the display: its first layout, and the zone that covers the same place on a remaining display.
public struct DisplayScene: Codable, Identifiable, Equatable {
    public var id: UUID
    /// What the user called it; empty until it is renamed (the app names it by its place then).
    public var name: String
    /// The layout of each display, by the display's identifier.
    public var layouts: [String: UUID]
    /// Where the windows of a zone go when the zone's display is unplugged: the zones to try, the first that is on a connected display first; none listed, they go where the layouts say.
    public var moves: [UUID: [UUID]]

    public init(id: UUID = UUID(), name: String = "", layouts: [String: UUID] = [:], moves: [UUID: [UUID]] = [:]) {
        self.id = id
        self.name = name
        self.layouts = layouts
        self.moves = moves
    }
}

extension DisplayScene {
    private enum CodingKeys: String, CodingKey { case id, name, layouts, moves }

    /// A scene saved before a zone could have several destinations has one for each zone.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        layouts = try c.decode([String: UUID].self, forKey: .layouts)
        if let several = try? c.decode([UUID: [UUID]].self, forKey: .moves) {
            moves = several
        } else {
            moves = (try c.decode([UUID: UUID].self, forKey: .moves)).mapValues { [$0] }
        }
    }
}
