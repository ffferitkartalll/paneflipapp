import Foundation
import PaneFlipCore

/// In-memory DocumentStore for tests.
final class MemoryStore: DocumentStore {
    private var blobs: [String: Data] = [:]

    func load<T: Decodable>(_ type: T.Type, named name: String) -> T? {
        blobs[name].flatMap { try? JSONDecoder().decode(T.self, from: $0) }
    }

    func save<T: Encodable>(_ value: T, named name: String) {
        blobs[name] = try? JSONEncoder().encode(value)
    }
}
