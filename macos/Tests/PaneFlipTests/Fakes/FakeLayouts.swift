import CoreGraphics
import Foundation
import PaneFlipCore

/// Takes the changes of a layout and keeps them, as the service does with the repository, and remembers what was asked.
final class FakeLayouts: LayoutManaging {
    let repository: LayoutRepository
    private(set) var updates: [(key: String, id: UUID, strip: StripLayout, animated: Bool)] = []

    init(repository: LayoutRepository) { self.repository = repository }

    func updateLayout(key: String, id: UUID, strip: StripLayout, animated: Bool) {
        updates.append((key, id, strip, animated))
        repository.setStrip(strip, ofLayout: id, key: key)
    }

    @discardableResult func addLayout(for key: String, preset: LayoutPreset) -> NamedLayout { fatalError("not used") }
    func duplicate(key: String, id: UUID) {}
    func importLayout(for key: String, _ layout: NamedLayout) {}
    func removeLayout(key: String, id: UUID) {}
    func activate(key: String, id: UUID) {}
    func deactivate(key: String) {}
    func setStartApp(key: String, id: UUID, bundleID: String, chosen: Bool) {}
    func setZoneName(key: String, id: UUID, zone: UUID, to name: String) {}
    func rename(key: String, id: UUID, to name: String) {}
    func setDefaultZone(key: String, id: UUID, to zone: UUID?) {}
}
