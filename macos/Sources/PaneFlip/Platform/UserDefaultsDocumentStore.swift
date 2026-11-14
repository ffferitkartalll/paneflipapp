import Foundation
import OSLog
import PaneFlipCore

/// Keeps each document as JSON under its name in UserDefaults: the one file that holds the settings too, so everything the app remembers is in one place.
/// A document an earlier version kept as `<name>.json` in a folder (Application Support/PaneFlip) is carried over the first time it is asked for, and its file removed.
final class UserDefaultsDocumentStore: DocumentStore {
    private let defaults: UserDefaults
    private let formerDirectory: URL

    init(defaults: UserDefaults = .standard, formerDirectory: URL = UserDefaultsDocumentStore.defaultFormerDirectory) {
        self.defaults = defaults
        self.formerDirectory = formerDirectory
    }

    static var defaultFormerDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("PaneFlip", isDirectory: true)
    }

    func load<T: Decodable>(_ type: T.Type, named name: String) -> T? {
        carryOver(name)
        guard let data = defaults.data(forKey: name) else { return nil }
        if let value = try? JSONDecoder().decode(T.self, from: data) { return value }
        // The document is there but cannot be read (damaged, or a newer format). Keep it: the next save would replace it.
        defaults.set(data, forKey: name + ".bak")
        return nil
    }

    func save<T: Encodable>(_ value: T, named name: String) {
        do { defaults.set(try JSONEncoder().encode(value), forKey: name) }
        catch { Self.log.error("Could not save \(name, privacy: .public): \(error.localizedDescription, privacy: .public)") }
    }

    private static let log = Logger(subsystem: "PaneFlip", category: "store")

    private func carryOver(_ name: String) {
        let files = FileManager.default
        let file = formerDirectory.appendingPathComponent("\(name).json")
        guard let data = try? Data(contentsOf: file) else { return }
        if defaults.data(forKey: name) == nil { defaults.set(data, forKey: name) }
        try? files.removeItem(at: file)
        // The folder goes with its last file only: something else may be kept in it.
        if (try? files.contentsOfDirectory(atPath: formerDirectory.path))?.isEmpty == true { try? files.removeItem(at: formerDirectory) }
    }
}
