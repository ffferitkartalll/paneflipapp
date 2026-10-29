import Foundation

/// One serial queue for each app: what is asked of an app that answers slowly (a mail client) waits in the queue of that app, and holds up neither the main
/// thread nor the other apps.
final class PerAppQueues {
    private let lock = NSLock()
    private var queues: [pid_t: DispatchQueue] = [:]

    func queue(for pid: pid_t) -> DispatchQueue {
        lock.lock()
        defer { lock.unlock() }
        if let known = queues[pid] { return known }
        let made = DispatchQueue(label: "PaneFlip.app.\(pid)", qos: .userInteractive)
        queues[pid] = made
        return made
    }
}
