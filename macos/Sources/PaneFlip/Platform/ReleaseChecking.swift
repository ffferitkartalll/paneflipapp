/// Asks where the newest release is published.
protocol ReleaseChecking {
    func latestRelease() async throws -> ReleaseInfo
}
