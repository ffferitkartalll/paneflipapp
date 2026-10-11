import CoreGraphics
import Foundation
import Observation

/// Owns every screen's layouts and persists them. Knows nothing about windows: it only stores layout data.
/// Screens are addressed by an opaque key ("displayUUID|desktopID").
@Observable
public final class LayoutRepository {
    public private(set) var screens: [String: ScreenLayouts] = [:] {
        didSet { store.save(screens, named: Self.documentName) }
    }
    @ObservationIgnored private let store: DocumentStore
    private static let documentName = "layouts-v2"

    public init(store: DocumentStore) {
        self.store = store
        if let loaded = store.load([String: ScreenLayouts].self, named: Self.documentName) { screens = loaded }
    }

    public func layouts(for key: String) -> [NamedLayout] { screens[key]?.layouts ?? [] }
    public func activeLayout(for key: String) -> NamedLayout? { screens[key]?.active }
    public func layout(id: UUID, key: String) -> NamedLayout? { screens[key]?.layouts.first { $0.id == id } }

    /// Every zone identifier of every layout (active or not).
    public var allZoneIDs: Set<UUID> {
        Set(screens.values.flatMap { $0.layouts.flatMap { $0.root.leafIDs } })
    }

    @discardableResult
    public func addLayout(for key: String, named name: String? = nil) -> NamedLayout {
        var s = screens[key] ?? ScreenLayouts()
        let layout = NamedLayout(name: name ?? "Layout \(s.layouts.count + 1)", root: .leaf(UUID()))
        s.layouts.append(layout)
        if s.activeID == nil { s.activeID = layout.id }
        screens[key] = s
        return layout
    }

    public func setRoot(_ root: LayoutNode, ofLayout id: UUID, key: String) {
        guard var s = screens[key], let i = s.layouts.firstIndex(where: { $0.id == id }) else { return }
        s.layouts[i].root = root
        screens[key] = s
    }

    public func rename(layout id: UUID, key: String, to name: String) {
        guard var s = screens[key], let i = s.layouts.firstIndex(where: { $0.id == id }) else { return }
        s.layouts[i].name = name
        screens[key] = s
    }

    public func activate(layout id: UUID, key: String) {
        guard var s = screens[key], s.layouts.contains(where: { $0.id == id }) else { return }
        s.activeID = id
        screens[key] = s
    }

    public func removeLayout(id: UUID, key: String) {
        guard var s = screens[key] else { return }
        s.layouts.removeAll { $0.id == id }
        if s.activeID == id { s.activeID = s.layouts.first?.id }
        screens[key] = s
    }
}
