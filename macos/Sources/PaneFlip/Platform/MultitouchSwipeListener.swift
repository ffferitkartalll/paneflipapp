import Foundation
import PaneFlipCore

/// Reads the trackpad's touches from the system's private MultitouchSupport framework, the only place that has them:
/// public API gives scroll and swipe events, which the system keeps for itself when its own three-finger gestures are on.
/// Without the framework (or a trackpad) it does nothing.
final class MultitouchSwipeListener: TrackpadSwipeListening {
    private typealias Device = OpaquePointer
    private typealias Contact = @convention(c) (Device, UnsafeMutableRawPointer?, Int32, Double, Int32, UnsafeMutableRawPointer?) -> Int32
    private typealias CreateList = @convention(c) () -> Unmanaged<CFArray>?
    private typealias Register = @convention(c) (Device, Contact, UnsafeMutableRawPointer?) -> Int32
    private typealias Unregister = @convention(c) (Device, Contact) -> Int32
    private typealias Control = @convention(c) (Device, Int32) -> Int32
    private typealias Stop = @convention(c) (Device) -> Int32

    /// One touch in a frame is this many bytes; the centre of a finger on the pad (0 to 1) is a pair of Floats at 32.
    private static let touchStride = 96
    private static let positionOffset = 32
    /// A touch's state (an Int32 at 20): hovering fingers and ones just lifting are not on the pad. 3 and 4: touching.
    private static let stateOffset = 20
    private static let touching: ClosedRange<Int32> = 3 ... 4

    /// The same function for registering and unregistering (the framework matches them by address).
    private static let contact: Contact = { _, touches, count, time, _, refcon in
        guard let refcon else { return 0 }
        Unmanaged<MultitouchSwipeListener>.fromOpaque(refcon).takeUnretainedValue().handle(touches, Int(count), time)
        return 0
    }

    private let lock = NSLock()
    private var tracker = SwipeTracker()
    private var onEvent: ((SwipeTracker.Event) -> Void)?
    private var devices: [Device] = []
    private var list: CFArray?
    private var symbols: (stop: Stop, unregister: Unregister)?
    private var createList: CreateList?
    /// Looks every few seconds for a trackpad that was connected (or taken away) since the devices were listed.
    private var watcher: Timer?

    func start(onEvent: @escaping (SwipeTracker.Event) -> Void) {
        guard devices.isEmpty, let framework = dlopen("/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport", RTLD_LAZY),
              let createList = dlsym(framework, "MTDeviceCreateList"), let register = dlsym(framework, "MTRegisterContactFrameCallbackWithRefcon"),
              let unregister = dlsym(framework, "MTUnregisterContactFrameCallback"), let start = dlsym(framework, "MTDeviceStart"),
              let stop = dlsym(framework, "MTDeviceStop"),
              let found = unsafeBitCast(createList, to: CreateList.self)()?.takeRetainedValue() else { return }
        self.onEvent = onEvent
        self.createList = unsafeBitCast(createList, to: CreateList.self)
        tracker = SwipeTracker()
        list = found
        symbols = (unsafeBitCast(stop, to: Stop.self), unsafeBitCast(unregister, to: Unregister.self))
        for index in 0 ..< CFArrayGetCount(found) {
            guard let value = CFArrayGetValueAtIndex(found, index) else { continue }
            let device = OpaquePointer(value)
            devices.append(device)
            _ = unsafeBitCast(register, to: Register.self)(device, Self.contact, Unmanaged.passUnretained(self).toOpaque())
            _ = unsafeBitCast(start, to: Control.self)(device, 0)
        }
        watcher = Timer.scheduledTimer(withTimeInterval: 10, repeats: false) { [weak self] _ in self?.look(onEvent) }
    }

    private func look(_ onEvent: @escaping (SwipeTracker.Event) -> Void) {
        guard let createList, let current = createList()?.takeRetainedValue() else { return }
        if CFArrayGetCount(current) != devices.count {
            stop()
            start(onEvent: onEvent)
        } else {
            watcher = Timer.scheduledTimer(withTimeInterval: 10, repeats: false) { [weak self] _ in self?.look(onEvent) }
        }
    }

    func stop() {
        watcher?.invalidate()
        watcher = nil
        guard let symbols else { return }
        for device in devices {
            _ = symbols.unregister(device, Self.contact)
            _ = symbols.stop(device)
        }
        devices = []
        list = nil
        lock.lock()
        onEvent = nil
        lock.unlock()
    }

    /// Runs on the framework's own thread.
    private func handle(_ touches: UnsafeMutableRawPointer?, _ count: Int, _ time: Double) {
        var x = 0.0, fingers = 0
        if let touches {
            for index in 0 ..< count {
                let base = touches.advanced(by: index * Self.touchStride)
                guard Self.touching.contains(base.load(fromByteOffset: Self.stateOffset, as: Int32.self)) else { continue }
                x += Double(base.load(fromByteOffset: Self.positionOffset, as: Float.self))
                fingers += 1
            }
            if fingers > 0 { x /= Double(fingers) }
        }
        lock.lock()
        let events = tracker.frame(fingerCount: fingers, x: x, time: time)
        let deliver = onEvent
        lock.unlock()
        guard let deliver, !events.isEmpty else { return }
        DispatchQueue.main.async { events.forEach(deliver) }
    }
}
