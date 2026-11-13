import CoreGraphics
import ScreenCaptureKit

final class ScreenCaptureWindowSnapshots: WindowSnapshotting {

    private let windows = Windows()

    func prepare() { Task { await windows.reload(unlessNewerThan: 2) } }

    func snapshots(of refs: [WindowRef], completion: @escaping ([CGWindowID: WindowPicture]) -> Void) {
        Task {
            let found = await windows.windows(refs.map(\.id), maxAge: 60)
            let pictures = await withTaskGroup(of: (CGWindowID, WindowPicture?).self) { group -> [CGWindowID: WindowPicture] in
                for (id, window) in found { group.addTask { (id, await Self.picture(of: window)) } }
                var result: [CGWindowID: WindowPicture] = [:]
                for await (id, picture) in group { if let picture { result[id] = picture } }
                return result
            }
            await MainActor.run { completion(pictures) }
        }
    }

    private static func picture(of window: SCWindow) async -> WindowPicture? {
        let filter = SCContentFilter(desktopIndependentWindow: window)
        let configuration = SCStreamConfiguration()
        let scale = CGFloat(filter.pointPixelScale)
        configuration.width = Int(filter.contentRect.width * scale)
        configuration.height = Int(filter.contentRect.height * scale)
        configuration.showsCursor = false
        configuration.ignoreShadowsSingleWindow = true
        configuration.ignoreGlobalClipSingleWindow = true
        // The property does not keep its colour alive: a colour made here would be freed before the capture reads it.
        configuration.backgroundColor = .clear
        guard let image = try? await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration) else { return nil }
        let squared = WindowCorners.squared(image)
        return WindowPicture(image: squared.image, frame: currentFrame(of: window), cornerRadius: CGFloat(squared.radius) / scale)
    }

    /// Where the window stands now. The list of windows is kept for up to a minute (`Windows`), so the frame it holds can be from a moment when the window waited at the display's
    /// edge (a picture that starts from there, over nothing, while the real window goes): the window server is asked again, which is cheap for one window.
    private static func currentFrame(of window: SCWindow) -> CGRect {
        guard let info = (CGWindowListCopyWindowInfo(.optionIncludingWindow, window.windowID) as? [[String: Any]])?.first,
              let bounds = info[kCGWindowBounds as String] as? [String: CGFloat],
              let x = bounds["X"], let y = bounds["Y"], let width = bounds["Width"], let height = bounds["Height"] else { return window.frame }
        return CGRect(x: x, y: y, width: width, height: height)
    }
}
