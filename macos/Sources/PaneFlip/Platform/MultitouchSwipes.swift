import AppKit
import PaneFlipCore

/// Hears three and four fingers on the trackpad through the system's private multitouch framework, which reports every finger on it
/// (scroll events know only of two). Three fingers lead the windows of a zone, four the layout of the screen. The framework is loaded
/// when the app starts: if the system does not have it, nothing is heard and the rest of the app works as before.
/// shortcut: the devices are listed once at start (and again after waking), so a trackpad connected later is heard after the next wake.
final class MultitouchSwipes: ScrollSwitchListening {
    private typealias Report = @convention(c) (UnsafeMutableRawPointer?, UnsafeMutableRawPointer?, Int32, Double, Int32, UnsafeMutableRawPointer?) -> Int32
    private typealias Devices = @convention(c) () -> Unmanaged<CFArray>?
    private typealias Register = @convention(c) (UnsafeMutableRawPointer, Report, UnsafeMutableRawPointer?) -> Void
    private typealias Unregister = @convention(c) (UnsafeMutableRawPointer, Report) -> Void
    private typealias Switch = @convention(c) (UnsafeMutableRawPointer, Int32) -> Void
    private typealias Stop = @convention(c) (UnsafeMutableRawPointer) -> Void

    /// One finger in a report: its state at byte 20 (3 and 4: touching), its place across and up the trackpad at bytes 32 and 36 (0 to 1).
    private static let touchSize = 96

    private let library = dlopen("/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport", RTLD_NOW)
    private var devices: CFArray?
    private var onEvent: ((ScrollSwitchEvent) -> Void)?
    /// How far the content goes for each point the fingers scroll; read when a swipe begins.
    private let gain: () -> CGFloat
    private var swipeGain: CGFloat = 1
    /// Whether the settings give the trackpad's three and four fingers to the app; read when a swipe begins.
    private let isOn: () -> Bool
    private var listening = false
    /// The reports come on the system's own thread, one after the other.
    private let lock = NSLock()
    private var swipe = FingerSwipe()
    private var wake: NSObjectProtocol?

    init(gain: @escaping () -> CGFloat, isOn: @escaping () -> Bool) {
        self.gain = gain
        self.isOn = isOn
    }

    deinit {
        stopDevices()
        if let wake { NSWorkspace.shared.notificationCenter.removeObserver(wake) }
    }

    func start(onEvent: @escaping (ScrollSwitchEvent) -> Void) {
        self.onEvent = onEvent
        startDevices()
        wake = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.stopDevices()
            self?.startDevices()
        }
    }

    private func symbol<T>(_ name: String, as type: T.Type) -> T? {
        library.flatMap { dlsym($0, name) }.map { unsafeBitCast($0, to: type) }
    }

    private static let report: Report = { _, touches, count, time, _, refcon in
        guard let refcon, let touches else { return 0 }
        Unmanaged<MultitouchSwipes>.fromOpaque(refcon).takeUnretainedValue().receive(touches, Int(count), time)
        return 0
    }

    private func startDevices() {
        guard let list = symbol("MTDeviceCreateList", as: Devices.self), let register = symbol("MTRegisterContactFrameCallbackWithRefcon", as: Register.self),
              let start = symbol("MTDeviceStart", as: Switch.self) else { return }
        // The framework prints a line about every trackpad it finds ("Recognized … family"); that is not ours to show.
        fflush(stdout)
        let console = dup(STDOUT_FILENO), quiet = open("/dev/null", O_WRONLY)
        dup2(quiet, STDOUT_FILENO)
        defer {
            fflush(stdout)
            dup2(console, STDOUT_FILENO)
            close(console)
            close(quiet)
        }
        guard let all = list()?.takeRetainedValue() else { return }
        devices = all
        for index in 0..<CFArrayGetCount(all) {
            guard let device = CFArrayGetValueAtIndex(all, index) else { continue }
            let pointer = UnsafeMutableRawPointer(mutating: device)
            register(pointer, Self.report, Unmanaged.passUnretained(self).toOpaque())
            start(pointer, 0)
        }
    }

    private func stopDevices() {
        guard let all = devices, let unregister = symbol("MTUnregisterContactFrameCallback", as: Unregister.self),
              let stop = symbol("MTDeviceStop", as: Stop.self) else { return }
        for index in 0..<CFArrayGetCount(all) {
            guard let device = CFArrayGetValueAtIndex(all, index) else { continue }
            let pointer = UnsafeMutableRawPointer(mutating: device)
            unregister(pointer, Self.report)
            stop(pointer)
        }
        devices = nil
        lock.lock()
        swipe = FingerSwipe()
        lock.unlock()
    }

    /// One report: how many fingers touch, and where their centre is.
    private func receive(_ touches: UnsafeMutableRawPointer, _ count: Int, _ time: TimeInterval) {
        var touching = 0
        var x = 0.0, y = 0.0
        for index in 0..<max(count, 0) {
            let touch = touches + index * Self.touchSize
            let px = Double(touch.load(fromByteOffset: 32, as: Float.self)), py = Double(touch.load(fromByteOffset: 36, as: Float.self))
            // A report that does not read as this layout (the system changed it) is left alone rather than taken for fingers.
            guard (0...1).contains(px), (0...1).contains(py) else { return }
            let state = touch.load(fromByteOffset: 20, as: Int32.self)
            guard state == 3 || state == 4 else { continue }
            touching += 1
            x += px
            y += py
        }
        let n = Double(max(touching, 1))
        lock.lock()
        let outputs = swipe.add(fingers: touching, x: x / n, y: y / n, at: time)
        lock.unlock()
        guard !outputs.isEmpty else { return }
        DispatchQueue.main.async { [weak self] in outputs.forEach { self?.deliver($0) } }
    }

    private func deliver(_ output: FingerSwipe.Output) {
        switch output {
        case .began(let fingers):
            listening = isOn()
            guard listening else { return }
            swipeGain = gain()
            onEvent?(.began(fingers == 3 ? .windows : .strip))
        case .moved(let delta, let time): if listening { onEvent?(.moved(delta * swipeGain, at: time)) }
        case .ended:
            if listening { onEvent?(.ended) }
            listening = false
        }
    }
}
