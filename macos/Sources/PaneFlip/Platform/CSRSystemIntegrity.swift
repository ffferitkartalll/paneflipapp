import Foundation
import PaneFlipCore

/// Reads the configuration word of the System Integrity Protection from the system. The call is found at run time: it is in the system's own library but not in the SDK's headers.
struct CSRSystemIntegrity: SystemIntegrityReading {
    private typealias ActiveConfig = @convention(c) (UnsafeMutablePointer<UInt32>) -> Int32

    func read() -> SystemIntegrity? {
        guard let symbol = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "csr_get_active_config") else { return nil }   // RTLD_DEFAULT
        var config: UInt32 = 0
        guard unsafeBitCast(symbol, to: ActiveConfig.self)(&config) == 0 else { return nil }
        return SystemIntegrity(config: config)
    }
}
