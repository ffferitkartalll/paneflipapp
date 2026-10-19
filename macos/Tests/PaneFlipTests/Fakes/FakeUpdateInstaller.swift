import Foundation

/// Installs nothing; fails when asked to.
final class FakeUpdateInstaller: UpdateInstalling {
    var fails = false
    private(set) var installed: [ReleaseInfo] = []

    func install(_ release: ReleaseInfo) async throws {
        installed.append(release)
        if fails { throw URLError(.cannotConnectToHost) }
    }
}
