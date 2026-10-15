import Foundation

/// A request to show the apps of a layout, scrolled to one zone. Every request is a new value, so asking for the
/// same zone again shows it again.
struct OrderingTarget: Equatable {
    let layoutID: UUID
    let zoneID: UUID?
    let request = UUID()
}
