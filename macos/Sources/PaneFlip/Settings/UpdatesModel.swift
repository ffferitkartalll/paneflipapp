import Foundation
import Observation
import PaneFlipCore

/// The state behind the Updates tab: whether a newer release exists, found out when the user asks.
@Observable
final class UpdatesModel {
    enum State: Equatable {
        case idle, checking, upToDate, failed
        case available(ReleaseInfo)
    }

    private(set) var state = State.idle
    /// The version of this app, as shown to the user.
    let currentVersion: String
    let installedWithHomebrew: Bool

    @ObservationIgnored private let checker: ReleaseChecking

    init(currentVersion: String, checker: ReleaseChecking, installSource: InstallSourceDetecting) {
        self.currentVersion = currentVersion
        self.checker = checker
        installedWithHomebrew = installSource.isHomebrew
    }

    @MainActor
    func check() async {
        guard state != .checking else { return }
        state = .checking
        do {
            let latest = try await checker.latestRelease()
            if let current = AppVersion(currentVersion), latest.version > current { state = .available(latest) } else { state = .upToDate }
        } catch {
            state = .failed
        }
    }
}
