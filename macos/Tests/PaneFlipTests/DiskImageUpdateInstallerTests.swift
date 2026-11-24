import XCTest

final class DiskImageUpdateInstallerTests: XCTestCase {
    /// The one gate between a downloaded file and the swap: an app that is not signed like this one must not pass.
    func testAnUnsignedAppIsRefused() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("UpdateGate-\(UUID().uuidString)")
        let app = folder.appendingPathComponent("PaneFlip.app")
        try FileManager.default.createDirectory(at: app.appendingPathComponent("Contents/MacOS"), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        XCTAssertFalse(DiskImageUpdateInstaller.isSignedLikeThisApp(app))
    }

    func testAMissingAppIsRefused() {
        XCTAssertFalse(DiskImageUpdateInstaller.isSignedLikeThisApp(URL(fileURLWithPath: "/nonexistent/PaneFlip.app")))
    }
}
