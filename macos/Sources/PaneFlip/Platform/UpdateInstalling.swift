/// Puts a newer release in place of the running app.
protocol UpdateInstalling {
    /// Downloads the release and replaces the app with it; the app then quits and the new one starts. Throws when it could not be
    /// done, with the app untouched.
    func install(_ release: ReleaseInfo) async throws
}
