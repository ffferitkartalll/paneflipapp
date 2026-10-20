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
    /// How long the app has to quit after an install before it is taken to have failed (the helper that swaps the app gives up
    /// after about 30 seconds).
    @ObservationIgnored private let quitGrace: TimeInterval

    init(currentVersion: String, checker: ReleaseChecking, installer: UpdateInstalling, quitGrace: TimeInterval = 35) {
        self.currentVersion = currentVersion
        self.checker = checker
        self.installer = installer
        self.quitGrace = quitGrace
    }

    /// Installs the release that was found. The app quits when it worked.
    @MainActor
    func install() async {
        guard case .available(let release) = state else { return }
        state = .installing(release)
        do { try await installer.install(release) } catch {
            state = .installFailed(release)
            return
        }
        // The app quits by itself when it worked. If it is still here after the grace, it did not.
        Task { [weak self, quitGrace] in
            try? await Task.sleep(for: .seconds(quitGrace))
            if let self, case .installing = state { state = .installFailed(release) }
        }
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
