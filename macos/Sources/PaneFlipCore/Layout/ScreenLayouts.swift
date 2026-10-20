import Foundation

/// The layouts of one display, shared by all its desktops, and which of them each desktop uses.
public struct ScreenLayouts: Codable, Equatable {
    public var layouts: [NamedLayout]
    /// The layout of each desktop, by the desktop's part of the screen key ("d2"). A desktop not named here has none.
    public var byDesktop: [String: UUID]
    /// Documents from before layouts were shared name one active layout per entry; it moves into `byDesktop` when loaded.
    var activeID: UUID?

    public init(layouts: [NamedLayout] = [], byDesktop: [String: UUID] = [:], activeID: UUID? = nil) {
        self.layouts = layouts
        self.byDesktop = byDesktop
        self.activeID = activeID
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        layouts = try c.decode([NamedLayout].self, forKey: .layouts)
        byDesktop = try c.decodeIfPresent([String: UUID].self, forKey: .byDesktop) ?? [:]
        activeID = try c.decodeIfPresent(UUID.self, forKey: .activeID)
    }

    /// The layout the entry named active before layouts were shared.
    var legacyActive: UUID? { activeID ?? layouts.first?.id }
}
