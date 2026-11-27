/// What the Mac's System Integrity Protection allows, from its configuration word (`csr_get_active_config`). Pure.
public struct SystemIntegrity: Equatable {
    /// The restrictions that must be off for a payload of ours to be loaded into the Dock: on the file system (0x2), on `task_for_pid` (0x4) and on nvram (0x40).
    private static let needed: UInt32 = 0x2 | 0x4 | 0x40

    private let config: UInt32

    public init(config: UInt32) { self.config = config }

    /// Whether those restrictions are all off. With SIP on (a word of 0), or off in part, the app works as it does for everyone.
    public var allowsDockPayload: Bool { config & Self.needed == Self.needed }
}
