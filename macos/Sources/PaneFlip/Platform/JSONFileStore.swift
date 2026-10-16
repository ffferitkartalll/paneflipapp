import Foundation
import OSLog
import PaneFlipCore

/// Stores each document as `<name>.json` in a directory (Application Support/PaneFlip by default).
final class JSONFileStore: DocumentStore {
    private let directory: URL

    init(directory: URL = JSONFileStore.defaultDirectory) {
        self.directory = directory
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    static var defaultDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("PaneFlip", isDirectory: true)
    }

    func load<T: Decodable>(_ type: T.Type, named name: String) -> T? {
        guard let data = try? Data(contentsOf: url(name)) else { return nil }
        if let value = try? JSONDecoder().decode(T.self, from: data) { return value }
        // The file exists but cannot be read (damaged, or a newer format). Keep it: the next save would replace it.
        let backup = url(name).appendingPathExtension("bak")
        try? FileManager.default.removeItem(at: backup)
        try? FileManager.default.copyItem(at: url(name), to: backup)
        return nil
    }

    func save<T: Encodable>(_ value: T, named name: String) {
        do { try JSONEncoder().encode(value).write(to: url(name), options: .atomic) }
        catch { Self.log.error("Could not save \(name, privacy: .public): \(error.localizedDescription, privacy: .public)") }
    }

    private static let log = Logger(subsystem: "PaneFlip", category: "store")

    private func url(_ name: String) -> URL { directory.appendingPathComponent("\(name).json") }
}
