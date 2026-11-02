import AppKit
import IOKit
import IOKit.hidsystem

/// Maps the key with `hidutil`, which holds until the next restart (the app gives it back when it quits; after a crash it stays until a
/// restart or until the setting is switched off and on again). shortcut: it replaces any other `hidutil` key mapping while it is on.
final class HIDCapsLockControl: CapsLockControlling {
    private static let capsLock = 0x700000039, f18 = 0x70000006D
    private var remapped = false

    init() {
        NotificationCenter.default.addObserver(forName: NSApplication.willTerminateNotification, object: nil, queue: .main) { [weak self] _ in
            self?.remap(false)
        }
    }

    func remap(_ enabled: Bool) {
        guard enabled != remapped else { return }
        let mapping = enabled ? [["HIDKeyboardModifierMappingSrc": Self.capsLock, "HIDKeyboardModifierMappingDst": Self.f18]] : []
        guard let json = try? JSONSerialization.data(withJSONObject: ["UserKeyMapping": mapping]),
              let text = String(data: json, encoding: .utf8) else { return }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/hidutil")
        process.arguments = ["property", "--set", text]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        guard (try? process.run()) != nil else { return }
        process.waitUntilExit()
        if process.terminationStatus == 0 { remapped = enabled }
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
