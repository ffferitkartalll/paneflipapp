import Foundation

/// An app installed on this Mac, running or not.
struct InstalledApp: Equatable {
    let bundleID: String
    let name: String
}
