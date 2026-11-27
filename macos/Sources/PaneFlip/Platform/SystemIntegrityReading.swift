import PaneFlipCore

/// The state of the Mac's System Integrity Protection.
protocol SystemIntegrityReading {
    /// What the protection allows now, or nil when the system does not say (the app then works as it does with the protection on).
    func read() -> SystemIntegrity?
}
