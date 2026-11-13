import CoreGraphics
import Foundation

/// Listens with an event tap, which (unlike a monitor) can keep the click from the app under the pointer. A click of the wheel button is taken when `zone` names a zone for it
/// (the app asks the keys and the pointer); its release goes the same way.
final class EventTapMiddleClick: MiddleClickListening {
    private var tap: CFMachPort?
    private var onClick: ((UUID) -> Void)?
    private let zone: () -> UUID?
    /// The press was taken: its release is too.
    private var taken = false

    init(zone: @escaping () -> UUID?) { self.zone = zone }

    func start(onClick: @escaping (UUID) -> Void) {
        self.onClick = onClick
        let callback: CGEventTapCallBack = { _, type, event, refcon in
            guard let refcon else { return Unmanaged.passUnretained(event) }
            return Unmanaged<EventTapMiddleClick>.fromOpaque(refcon).takeUnretainedValue().handle(type, event)
        }
        let mask = [CGEventType.otherMouseDown, .otherMouseUp].reduce(CGEventMask(0)) { $0 | CGEventMask(1 << $1.rawValue) }
        guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap, eventsOfInterest: mask,
                                          callback: callback, userInfo: Unmanaged.passUnretained(self).toOpaque()) else { return }
        self.tap = tap
        CFRunLoopAddSource(CFRunLoopGetMain(), CFMachPortCreateRunLoopSource(nil, tap, 0), .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    private func handle(_ type: CGEventType, _ event: CGEvent) -> Unmanaged<CGEvent>? {
        // The system switches a tap off when it is too slow once; switch it back on.
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        guard event.getIntegerValueField(.mouseEventButtonNumber) == 2 else { return Unmanaged.passUnretained(event) }
        if type == .otherMouseUp {
            defer { taken = false }
            return taken ? nil : Unmanaged.passUnretained(event)
        }
        guard let zone = zone() else { return Unmanaged.passUnretained(event) }
        taken = true
        DispatchQueue.main.async { [weak self] in self?.onClick?(zone) }
        return nil
    }
}
