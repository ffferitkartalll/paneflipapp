import AppKit
import IOKit
import IOKit.hidsystem

/// Maps the key with `hidutil`, which holds until the next restart. The app gives it back when it quits; a small shell process waits for the app
/// and gives it back when the app is killed (a stop from Xcode, a crash), and the next start with the setting off clears a mapping left when
/// even that did not run, if it is exactly ours. shortcut: while the setting is on it
/// replaces any other `hidutil` key mapping. `hidutil` runs off the main thread and is given two seconds.
final class HIDCapsLockControl: CapsLockControlling {
    private static let capsLock = 0x700000039, f18 = 0x70000006D
    private let queue = DispatchQueue(label: "hidutil")
    private var wanted: Bool?
    private var watcher: Process?

    init() {
        NotificationCenter.default.addObserver(forName: NSApplication.willTerminateNotification, object: nil, queue: .main) { [weak self] _ in
            guard let self, wanted == true else { return }
            queue.sync { self.apply(false) }
        }
    }

    func remap(_ enabled: Bool) {
        guard enabled != wanted else { return }
        wanted = enabled
        queue.async { [self] in apply(enabled) }
    }

    private func apply(_ enabled: Bool) {
        watcher?.terminate()
        watcher = nil
        if enabled { watcher = Self.watch(ProcessInfo.processInfo.processIdentifier) } else {
            // Only our own mapping is taken away.
            // `--get` answers once for every keyboard service, so the keys of all the mappings are read, and none but ours may be among them.
            guard let current = Self.hidutil(["property", "--get", "UserKeyMapping"]) else { return }
            let keys = Set(current.matches(of: /HIDKeyboardModifierMapping(?:Src|Dst) = (\d+)/).compactMap { Int($0.output.1) })
            guard !keys.isEmpty, keys.isSubset(of: [Self.capsLock, Self.f18]) else { return }
        }
        _ = Self.hidutil(["property", "--set", Self.mapping(enabled)])
    }

    private static func mapping(_ enabled: Bool) -> String {
        let keys = enabled ? "{\"HIDKeyboardModifierMappingSrc\":\(capsLock),\"HIDKeyboardModifierMappingDst\":\(f18)}" : ""
        return "{\"UserKeyMapping\":[\(keys)]}"
    }

    /// A shell that outlives the app when the app is killed, and then takes the mapping away.
    private static func watch(_ pid: Int32) -> Process? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", "while kill -0 \(pid) 2>/dev/null; do sleep 1; done; /usr/bin/hidutil property --set '\(mapping(false))'"]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        return (try? process.run()) == nil ? nil : process
    }

    /// The output of `hidutil`, nil when it failed or did not answer in time.
    private static func hidutil(_ arguments: [String]) -> String? {
        let process = Process(), output = Pipe(), done = DispatchSemaphore(value: 0)
        process.executableURL = URL(fileURLWithPath: "/usr/bin/hidutil")
        process.arguments = arguments
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        process.terminationHandler = { _ in done.signal() }
        guard (try? process.run()) != nil else { return nil }
        guard done.wait(timeout: .now() + 2) == .success else { process.terminate(); return nil }
        guard process.terminationStatus == 0 else { return nil }
        return String(data: output.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)
    }

    func toggleLock() {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching(kIOHIDSystemClass))
        guard service != 0 else { return }
        defer { IOObjectRelease(service) }
        var connect: io_connect_t = 0
        guard IOServiceOpen(service, mach_task_self_, UInt32(kIOHIDParamConnectType), &connect) == KERN_SUCCESS else { return }
        defer { IOServiceClose(connect) }
        var on = false
        IOHIDGetModifierLockState(connect, Int32(kIOHIDCapsLockState), &on)
        IOHIDSetModifierLockState(connect, Int32(kIOHIDCapsLockState), !on)
    }
}
