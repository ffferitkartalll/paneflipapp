import AppKit
import Observation
import PaneFlipCore

/// Records a key or key combination: everything pressed together counts, and it is committed once all keys are released.
@Observable
final class KeyRecorder {
    private(set) var isRecording = false
    private(set) var preview = ""
    @ObservationIgnored private var down: [Int: String] = [:]
    @ObservationIgnored private var peak: [Int: String] = [:]
    @ObservationIgnored private var monitor: Any?
    @ObservationIgnored private var onFinish: ((SnapTrigger) -> Void)?

    func start(onFinish: @escaping (SnapTrigger) -> Void) {
        stop()
        self.onFinish = onFinish
        isRecording = true
        preview = ""
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp, .flagsChanged]) { [weak self] event in
            self?.handle(event)
            return nil   // swallow while recording
        }
    }

    func stop() {
        if let m = monitor { NSEvent.removeMonitor(m) }
        monitor = nil
        isRecording = false
        down = [:]
        peak = [:]
    }

    private func press(_ code: Int, _ name: String) {
        down[code] = name
        peak[code] = name
        preview = peak.sorted { $0.key < $1.key }.map(\.value).joined(separator: " + ")
    }

    private func release(_ code: Int) {
        down[code] = nil
        guard down.isEmpty, !peak.isEmpty else { return }
        let trigger = SnapTrigger(keys: peak.sorted { $0.key < $1.key }.map { .init(code: $0.key, name: $0.value) })
        let finish = onFinish
        stop()
        finish?(trigger)
    }

    private func handle(_ event: NSEvent) {
        let code = Int(event.keyCode)
        switch event.type {
        case .keyDown:
            if event.isARepeat { return }
            if code == 53 && down.isEmpty { stop(); return }   // Esc alone cancels
            press(code, SnapTrigger.name(forKeyCode: code, characters: event.charactersIgnoringModifiers))
        case .keyUp:
            release(code)
        case .flagsChanged:
            guard let mask = SnapTrigger.modifierMasks[code] else { return }
            if event.modifierFlags.rawValue & mask != 0 { press(code, SnapTrigger.name(forKeyCode: code, characters: nil)) }
            else { release(code) }
        default: break
        }
    }
}
