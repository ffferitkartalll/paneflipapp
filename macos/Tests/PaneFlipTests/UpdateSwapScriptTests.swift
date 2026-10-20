import XCTest

/// The script that swaps the app for the new one runs in temporary folders, with `true` in place of the program that opens the app.
final class UpdateSwapScriptTests: XCTestCase {
    private var folder: URL!
    private var app: URL { folder.appendingPathComponent("PaneFlip.app") }
    private var staged: URL { folder.appendingPathComponent(".PaneFlip-update.app") }
    private let gone: Int32 = 99_999_999   // no such process: the app has quit

    override func setUpWithError() throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("swap-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try make(app, marker: "old")
        try make(staged, marker: "new")
    }

    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: folder) }

    private func make(_ url: URL, marker: String) throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        try marker.write(to: url.appendingPathComponent("marker"), atomically: true, encoding: .utf8)
    }

    private func marker(of url: URL) -> String? { try? String(contentsOf: url.appendingPathComponent("marker"), encoding: .utf8) }

    @discardableResult
    private func run(waitingFor pid: Int32, patience: Int = 150, staged stagedURL: URL? = nil) throws -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = UpdateSwapScript.arguments(waitingFor: pid, app: app, staged: stagedURL ?? staged, open: "/usr/bin/true", patience: patience)
        try process.run()
        process.waitUntilExit()
        return process.terminationStatus
    }

    func testTheNewAppTakesThePlaceOfTheOldOne() throws {
        XCTAssertEqual(try run(waitingFor: gone), 0)
        XCTAssertEqual(marker(of: app), "new")
        XCTAssertFalse(FileManager.default.fileExists(atPath: staged.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: app.path + ".old"), "the old app is removed once the new one is in place")
    }

    func testTheOldAppComesBackWhenTheNewOneCannotBeMoved() throws {
        try run(waitingFor: gone, staged: folder.appendingPathComponent("missing.app"))
        XCTAssertEqual(marker(of: app), "old")
        XCTAssertFalse(FileManager.default.fileExists(atPath: app.path + ".old"))
    }

    func testAnAppThatDoesNotQuitLeavesEverythingAsItWasAndTheStagedCopyIsRemoved() throws {
        let status = try run(waitingFor: ProcessInfo.processInfo.processIdentifier, patience: 2)   // this test process stays alive
        XCTAssertNotEqual(status, 0)
        XCTAssertEqual(marker(of: app), "old")
        XCTAssertFalse(FileManager.default.fileExists(atPath: staged.path))
    }
}
