import Foundation

public struct NamedLayout: Codable, Identifiable, Equatable {
    public var id: UUID
    public var name: String
    public var root: LayoutNode

    public init(id: UUID = UUID(), name: String, root: LayoutNode) {
        self.id = id
        self.name = name
        self.root = root
    }
}
