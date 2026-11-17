import Foundation
import Observation

/// Owns the scenes and persists them. The first scene is the default one: it keeps its (empty) name and is never removed, only reset.
@Observable
public final class SceneRepository {
    struct Book: Codable, Equatable {
        var scenes: [DisplayScene]
        var activeID: UUID
        /// The displays that were connected at the last look, so that one plugged in again is noticed, whenever the app was off.
        var seen: Set<String> = []
    }

    private var book: Book { didSet { store.save(book, named: Self.documentName) } }
    @ObservationIgnored private let store: DocumentStore
    private static let documentName = "scenes-v1"

    public init(store: DocumentStore) {
        self.store = store
        if let loaded = store.load(Book.self, named: Self.documentName), !loaded.scenes.isEmpty {
            book = loaded
        } else {
            let first = DisplayScene()
            book = Book(scenes: [first], activeID: first.id)
        }
    }

    public var scenes: [DisplayScene] { book.scenes }
    public var activeScene: DisplayScene { book.scenes.first { $0.id == book.activeID } ?? book.scenes[0] }
    public func isDefault(_ id: UUID) -> Bool { book.scenes[0].id == id }

    public var seenDisplays: Set<String> {
        get { book.seen }
        set { if newValue != book.seen { book.seen = newValue } }
    }

    public func select(_ id: UUID) {
        guard book.scenes.contains(where: { $0.id == id }) else { return }
        book.activeID = id
    }

    @discardableResult
    public func add() -> DisplayScene {
        let scene = DisplayScene()
        book.scenes.append(scene)
        return scene
    }

    public func rename(_ id: UUID, to name: String) {
        guard !isDefault(id) else { return }
        update(id) { $0.name = name }
    }

    /// The default scene is never removed; the active scene that is removed gives way to the default one.
    public func remove(_ id: UUID) {
        guard !isDefault(id) else { return }
        book.scenes.removeAll { $0.id == id }
        if book.activeID == id { book.activeID = book.scenes[0].id }
    }

    /// Puts a scene back as it starts: no layouts chosen, no moves chosen, its name kept.
    public func reset(_ id: UUID) {
        update(id) { $0.layouts = [:]; $0.moves = [:] }
    }

    public func setLayout(_ layout: UUID, ofDisplay display: String, inScene id: UUID) {
        update(id) { $0.layouts[display] = layout }
    }

    /// The zones the windows of `zone` are sent to, the first to try first; none: they go where the layouts say.
    public func setMoves(ofZone zone: UUID, to destinations: [UUID], inScene id: UUID) {
        update(id) { $0.moves[zone] = destinations.isEmpty ? nil : destinations }
    }

    private func update(_ id: UUID, _ change: (inout DisplayScene) -> Void) {
        guard let i = book.scenes.firstIndex(where: { $0.id == id }) else { return }
        var copy = book
        change(&copy.scenes[i])
        if copy != book { book = copy }
    }
}
