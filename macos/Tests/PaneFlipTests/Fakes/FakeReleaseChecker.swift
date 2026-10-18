import Foundation
import PaneFlipCore

/// Answers with a release, or fails.
final class FakeReleaseChecker: ReleaseChecking {
    var release: ReleaseInfo? = ReleaseInfo(version: AppVersion("1.1")!, page: URL(string: "https://example.com/release")!)

    func latestRelease() async throws -> ReleaseInfo {
        guard let release else { throw URLError(.notConnectedToInternet) }
        return release
    }
}
