import Foundation
import os

/// Waits for a task, but not for ever: a call into the system that never answers (the capture service restarted, a permission changed) must not hold its callers.
enum TaskDeadline {
    /// Returns when `task` is done or `seconds` have passed, whichever comes first. A task that does not end is left running; nothing waits for it.
    static func wait(for task: Task<Void, Never>, seconds: TimeInterval) async {
        let resumed = OSAllocatedUnfairLock(initialState: false)
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            @Sendable func resumeOnce() {
                if !resumed.withLock({ let was = $0; $0 = true; return was }) { continuation.resume() }
            }
            Task { await task.value; resumeOnce() }
            Task { try? await Task.sleep(for: .seconds(seconds)); resumeOnce() }
        }
    }
}
