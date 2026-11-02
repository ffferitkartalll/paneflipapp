import CoreGraphics
import ScreenCaptureKit

extension ScreenCaptureWindowSnapshots {
    /// Listing the windows of the system takes a few hundred milliseconds, which would be the wait between a click
    /// and the slide. The list is kept for a moment and refreshed ahead of time (`prepare`).
    actor Windows {
        private var byID: [CGWindowID: SCWindow] = [:]
        private var loadedAt = Date.distantPast

        private var loading: Task<Void, Never>?

        /// One reload at a time: a caller that arrives meanwhile waits for it instead of starting a second one.
        func reload(unlessNewerThan age: TimeInterval = 0) async {
            if let loading { return await loading.value }
            guard Date().timeIntervalSince(loadedAt) > age else { return }
            let task = Task {
                guard let content = try? await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: false) else { return }
                self.store(content.windows)
            }
            loading = task
            await task.value
            loading = nil
        }

        private func store(_ list: [SCWindow]) {
            byID = Dictionary(list.map { ($0.windowID, $0) }, uniquingKeysWith: { first, _ in first })
            loadedAt = Date()
        }

        func windows(_ ids: [CGWindowID], maxAge: TimeInterval) async -> [CGWindowID: SCWindow] {
            if Date().timeIntervalSince(loadedAt) > maxAge || ids.contains(where: { byID[$0] == nil }) { await reload() }
            return byID.filter { ids.contains($0.key) }
        }
    }
}
