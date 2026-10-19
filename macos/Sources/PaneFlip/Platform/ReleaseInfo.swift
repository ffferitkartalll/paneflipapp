import Foundation
import PaneFlipCore

/// The newest published release.
struct ReleaseInfo: Equatable {
    let version: AppVersion
    /// Where its notes and download are.
    let page: URL

    /// The disk image of the release: the release page `…/releases/tag/v1.1` has it at `…/releases/download/v1.1/PaneFlip-1.1.dmg`.
    var diskImage: URL {
        page.deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("download").appendingPathComponent(page.lastPathComponent)
            .appendingPathComponent("PaneFlip-\(version).dmg")
    }
}
