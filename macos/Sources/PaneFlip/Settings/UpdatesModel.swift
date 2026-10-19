import Foundation
import Observation
import PaneFlipCore

/// The state behind the Updates tab: whether a newer release exists, found out when the user asks.
@Observable
final class UpdatesModel {
    enum State: Equatable {
        case idle, checking, upToDate, failed
        case available(ReleaseInfo)
        case installing(ReleaseInfo)
        case installFailed(ReleaseInfo)
    }

    private(set) var state = State.idle
    /// The version of this app, as shown to the user.
    let currentVersion: String

    @ObservationIgnored private let checker: ReleaseChecking
    @ObservationIgnored private let installer: UpdateInstalling

    init(currentVersion: String, checker: ReleaseChecking, installer: UpdateInstalling) {
        self.currentVersion = currentVersion
        self.checker = checker
        self.installer = installer
    }

    /// Installs the release that was found. The app quits when it worked.
    @MainActor
    func install() async {
        guard case .available(let release) = state else { return }
        state = .installing(release)
        do { try await installer.install(release) } catch { state = .installFailed(release) }
    }

    @MainActor
    func check() async {
        if state == .checking { return }
        if case .installing = state { return }
        state = .checking
        do {
            let latest = try await checker.latestRelease()
            if let current = AppVersion(currentVersion), latest.version > current { state = .available(latest) } else { state = .upToDate }
        } catch {
            state = .failed
        }
    }
}
