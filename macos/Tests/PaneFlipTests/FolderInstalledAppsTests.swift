import XCTest

final class FolderInstalledAppsTests: XCTestCase {
    private var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDown() { try? FileManager.default.removeItem(at: root) }

    private func makeApp(_ path: String, id: String) throws {
        let contents = root.appendingPathComponent(path).appendingPathComponent("Contents")
        try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
        let info: [String: Any] = ["CFBundleIdentifier": id, "CFBundleName": id]
        try (info as NSDictionary).write(to: contents.appendingPathComponent("Info.plist"))
    }

    func testAnAppInAFolderOfTheFolderIsFound() throws {
        try makeApp("Top.app", id: "test.top")
        try makeApp("Web Apps.localized/Inner.app", id: "test.inner")
        try makeApp("A/B/C/TooDeep.app", id: "test.deep")
        let ids = Set(FolderInstalledApps(folders: [root.path]).apps().map(\.bundleID))
        XCTAssertEqual(ids, ["test.top", "test.inner"])
    }
}
