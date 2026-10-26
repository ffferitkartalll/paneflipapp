import Dispatch

/// Tells when the system is short of memory, so what is kept for speed can go.
final class MemoryPressureWatch {
    private let source: DispatchSourceMemoryPressure

    init(onPressure: @escaping () -> Void) {
        source = DispatchSource.makeMemoryPressureSource(eventMask: [.warning, .critical], queue: .main)
        source.setEventHandler(handler: onPressure)
        source.resume()
    }
}
