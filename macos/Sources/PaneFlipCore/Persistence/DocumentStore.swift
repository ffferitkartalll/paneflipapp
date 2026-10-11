import Foundation

/// Port for persisting named Codable documents. The app supplies a JSON-file adapter; tests supply an in-memory one.
public protocol DocumentStore {
    func load<T: Decodable>(_ type: T.Type, named name: String) -> T?
    func save<T: Encodable>(_ value: T, named name: String)
}
