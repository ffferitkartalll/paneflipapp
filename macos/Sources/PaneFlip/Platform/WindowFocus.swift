import ApplicationServices
import CoreGraphics
import Foundation

@_silgen_name("GetProcessForPID")
private func processSerialNumber(forPID pid: pid_t, _ psn: UnsafeMutablePointer<ProcessSerialNumber>) -> OSStatus

/// Brings one window of an app forward and makes it the key window the way a click on it does: the app's other windows (on another display, say) stay where
/// they are. Asking the app to come forward brings all its windows with it.
enum WindowFocus {
    private typealias SetFront = @convention(c) (UnsafeMutablePointer<ProcessSerialNumber>, UInt32, UInt32) -> CGError
    private typealias PostEvent = @convention(c) (UnsafeMutablePointer<ProcessSerialNumber>, UnsafeMutablePointer<UInt8>) -> CGError

    /// The two calls of the system's window server, found when first needed: nothing is linked, and where they are missing `focus` says so.
    private static let calls: (setFront: SetFront, postEvent: PostEvent)? = {
        guard let handle = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_LAZY),
              let setFront = dlsym(handle, "_SLPSSetFrontProcessWithOptions"), let postEvent = dlsym(handle, "SLPSPostEventRecordTo") else { return nil }
        return (unsafeBitCast(setFront, to: SetFront.self), unsafeBitCast(postEvent, to: PostEvent.self))
    }()

    /// The "user generated" way of making a process frontmost: only the window named comes forward.
    private static let userGenerated: UInt32 = 0x200

    /// False when the system would not do it; the caller then asks the app to come forward.
    static func focus(_ ref: WindowRef) -> Bool {
        var psn = ProcessSerialNumber()
        guard let calls, processSerialNumber(forPID: ref.pid, &psn) == noErr, calls.setFront(&psn, ref.id, userGenerated) == .success else { return false }
        // Two events, as the system sends them when a window is clicked: the window becomes key, and the app's own idea of its key window follows.
        var window = ref.id
        for kind: UInt8 in [0x01, 0x02] {
            var bytes = [UInt8](repeating: 0, count: 0xf8)
            bytes[0x04] = 0xf8
            bytes[0x08] = kind
            bytes[0x3a] = 0x10
            withUnsafeBytes(of: &window) { bytes.replaceSubrange(0x3c ..< 0x40, with: $0) }
            bytes.replaceSubrange(0x20 ..< 0x30, with: [UInt8](repeating: 0xff, count: 0x10))
            _ = bytes.withUnsafeMutableBufferPointer { calls.postEvent(&psn, $0.baseAddress!) }
        }
        return true
    }
}
