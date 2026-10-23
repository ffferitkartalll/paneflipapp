import Foundation

/// A layout as a file that can be kept or shared.
extension NamedLayout {
    public func exported() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }

    /// The layout of a file, with zones of its own: importing the same file twice gives two layouts that share nothing.
    public static func imported(from data: Data) throws -> NamedLayout {
        let file = try JSONDecoder().decode(NamedLayout.self, from: data)
        var layout = file.copy(named: file.name)
        layout.startApps = file.startApps
        return layout
    }
}
