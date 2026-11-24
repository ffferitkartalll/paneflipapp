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
        guard file.isUsable else { throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "A value is out of the range the editor allows.")) }
        return file.copy(named: file.name)
    }

    /// Whether every number of a file stays inside what the layout editor can make: a ratio of 0 or 1.5, or a gap of 5000, would give zones with no size.
    private var isUsable: Bool {
        ([root] + leading.map(\.root) + trailing.map(\.root)).allSatisfy(\.hasUsableRatios)
            && (leading + trailing).allSatisfy { $0.width > 0 && $0.width.isFinite }
            && [gap, edgeMargin].allSatisfy { $0.map(AppSettings.gapRange.contains) ?? true }
            && (minZoneSize.map(AppSettings.minZoneSizeRange.contains) ?? true)
    }
}
