import Testing
@testable import PaneFlipCore

struct SystemIntegrityTests {
    @Test func withProtectionOnNothingIsAllowed() {
        #expect(!SystemIntegrity(config: 0).allowsDockPayload)
    }

    @Test func withProtectionOffAsOnTheOwnersMac() {
        // csrutil disable on this macOS: 0x86f.
        #expect(SystemIntegrity(config: 0x86f).allowsDockPayload)
    }

    @Test func offInPartIsNotEnough() {
        // Only the file system, or the file system and the debugging, but not nvram.
        #expect(!SystemIntegrity(config: 0x2).allowsDockPayload)
        #expect(!SystemIntegrity(config: 0x2 | 0x4).allowsDockPayload)
        #expect(SystemIntegrity(config: 0x2 | 0x4 | 0x40).allowsDockPayload)
    }
}
