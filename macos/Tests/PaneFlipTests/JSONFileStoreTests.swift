import XCTest

final class JSONFileStoreTests: XCTestCase {
    private var directory: URL!
    private var store: JSONFileStore!

    override func setUp() {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        store = JSONFileStore(directory: directory)
        addTeardownBlock { [directory] in try? FileManager.default.removeItem(at: directory!) }
    }

    func testSavedValueIsLoadedBack() {
        store.save(["a": 1], named: "doc")
        XCTAssertEqual(store.load([String: Int].self, named: "doc"), ["a": 1])
    }

    func testMissingFileIsNilAndLeavesNoBackup() {
        XCTAssertNil(store.load([String: Int].self, named: "doc"))
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.appendingPathComponent("doc.json.bak").path))
    }

    /// The next save would otherwise replace a file that only could not be read (damaged, or a newer format).
    func testUnreadableFileIsKeptAsBackupBeforeItCanBeOverwritten() throws {
        let original = Data("{ not json".utf8)
        try original.write(to: directory.appendingPathComponent("doc.json"))

        XCTAssertNil(store.load([String: Int].self, named: "doc"))
        store.save(["a": 1], named: "doc")

        XCTAssertEqual(try Data(contentsOf: directory.appendingPathComponent("doc.json.bak")), original)
        XCTAssertEqual(store.load([String: Int].self, named: "doc"), ["a": 1])
    }
}
