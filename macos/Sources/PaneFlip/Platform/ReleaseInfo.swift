import Foundation
import PaneFlipCore

/// The newest published release.
struct ReleaseInfo: Equatable {
    let version: AppVersion
    /// Where its notes and download are.
    let page: URL
}
