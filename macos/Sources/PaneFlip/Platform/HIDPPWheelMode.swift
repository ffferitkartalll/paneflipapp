import Foundation
import IOKit.hid
import PaneFlipCore

/// Asks a Logitech mouse how its wheel turns (SmartShift, HID++ 2.0 on the mouse's own HID interface) and keeps the last answer. Nothing is opened before the
/// first question: only a mouse whose driver smooths the wheel needs it, and opening a HID interface can make the system ask for the Input Monitoring permission;
/// without it the mouse stays silent and the mode unknown.
final class HIDPPWheelMode: WheelModeReading {
    private static let logitech = 0x046D
    private static let bufferSize = 64
    /// How soon the mouse is asked again, in seconds: a switch of the wheel shows by the next scroll after this.
    private static let refresh: TimeInterval = 0.5

    private var manager: IOHIDManager?
    /// The interfaces that could speak HID++ (an output report of 20 bytes), each with the buffer its reports arrive in.
    private var candidates: [IOHIDDevice: UnsafeMutablePointer<UInt8>] = [:]
    /// The one that has the SmartShift feature, and where it keeps it.
    private var device: IOHIDDevice?
    private var featureIndex: UInt8?
    private var current: WheelMode?
    private var lastQuestion: TimeInterval = 0

    deinit { candidates.values.forEach { $0.deallocate() } }

    func mode() -> WheelMode? {
        if manager == nil { start() }
        let now = ProcessInfo.processInfo.systemUptime
        if now - lastQuestion > Self.refresh {
            lastQuestion = now
            ask()
        }
        return current
    }

    private func start() {
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        self.manager = manager
        IOHIDManagerSetDeviceMatching(manager, [kIOHIDVendorIDKey: Self.logitech] as CFDictionary)
        let me = Unmanaged.passUnretained(self).toOpaque()
        IOHIDManagerRegisterDeviceMatchingCallback(manager, { context, _, _, device in
            guard let context else { return }
            Unmanaged<HIDPPWheelMode>.fromOpaque(context).takeUnretainedValue().found(device)
        }, me)
        IOHIDManagerRegisterDeviceRemovalCallback(manager, { context, _, _, device in
            guard let context else { return }
            Unmanaged<HIDPPWheelMode>.fromOpaque(context).takeUnretainedValue().lost(device)
        }, me)
        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
        IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
    }

    private func found(_ device: IOHIDDevice) {
        let size = IOHIDDeviceGetProperty(device, kIOHIDMaxOutputReportSizeKey as CFString) as? Int ?? 0
        guard size >= 20, candidates[device] == nil else { return }
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: Self.bufferSize)
        candidates[device] = buffer
        IOHIDDeviceRegisterInputReportCallback(device, buffer, Self.bufferSize, { context, _, sender, _, _, report, length in
            guard let context, let sender else { return }
            let bytes = Array(UnsafeBufferPointer(start: report, count: length))
            Unmanaged<HIDPPWheelMode>.fromOpaque(context).takeUnretainedValue()
                .received(bytes, from: Unmanaged<IOHIDDevice>.fromOpaque(sender).takeUnretainedValue())
        }, Unmanaged.passUnretained(self).toOpaque())
        IOHIDDeviceScheduleWithRunLoop(device, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
        lastQuestion = 0
    }

    private func lost(_ gone: IOHIDDevice) {
        candidates.removeValue(forKey: gone)?.deallocate()
        if gone == device {
            device = nil
            featureIndex = nil
            current = nil
        }
    }

    private func ask() {
        if let device, let featureIndex {
            send(SmartShift.modeQuestion(featureIndex: featureIndex), to: device)
        } else {
            for candidate in candidates.keys { send(SmartShift.featureQuestion(), to: candidate) }
        }
    }

    private func received(_ bytes: [UInt8], from sender: IOHIDDevice) {
        if device == nil, let index = SmartShift.featureIndex(inAnswer: bytes) {
            device = sender
            featureIndex = index
            send(SmartShift.modeQuestion(featureIndex: index), to: sender)
        } else if sender == device, let featureIndex, let mode = SmartShift.mode(inAnswer: bytes, featureIndex: featureIndex) {
            current = mode
        }
    }

    /// The call waits for the mouse, so it stays off the thread of the event tap that asks.
    private func send(_ report: [UInt8], to device: IOHIDDevice) {
        DispatchQueue.global(qos: .userInitiated).async {
            _ = IOHIDDeviceSetReport(device, kIOHIDReportTypeOutput, CFIndex(report[0]), report, report.count)
        }
    }
}
