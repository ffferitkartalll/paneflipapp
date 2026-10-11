import Foundation
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
        (try? Data(contentsOf: url(name))).flatMap { try? JSONDecoder().decode(T.self, from: $0) }
    }

    func save<T: Encodable>(_ value: T, named name: String) {
        if let data = try? JSONEncoder().encode(value) { try? data.write(to: url(name), options: .atomic) }
    }

    private func url(_ name: String) -> URL { directory.appendingPathComponent("\(name).json") }
}
