import Foundation
import PaneFlipCore

/// Calls back once a stream of events has been quiet for `WheelSteps.idle`: a swipe made of a smoothed free-spinning wheel has no touch phase to end it. One check is
/// pending at a time, and it looks again for as long as the events keep coming.
final class WheelIdle {
    private let onIdle: () -> Void
    private var last: TimeInterval = 0
    private var pending = false

    init(onIdle: @escaping () -> Void) { self.onIdle = onIdle }

    /// An event came.
    func touch() {
        last = ProcessInfo.processInfo.systemUptime
        watch(after: WheelSteps.idle)
    }

    private func watch(after delay: TimeInterval) {
        guard !pending else { return }
        pending = true
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in self?.check() }
    }

    private func check() {
        pending = false
        let quiet = ProcessInfo.processInfo.systemUptime - last
        guard quiet >= WheelSteps.idle else { return watch(after: WheelSteps.idle - quiet) }
        onIdle()
    }
}
