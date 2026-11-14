import XCTest

final class UserDefaultsDocumentStoreTests: XCTestCase {
    private let suite = "paneflip.tests"
    private var defaults: UserDefaults!
    private var directory: URL!
    private var store: UserDefaultsDocumentStore!

    override func setUp() {
        defaults = UserDefaults(suiteName: suite)
        defaults.removePersistentDomain(forName: suite)
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        store = UserDefaultsDocumentStore(defaults: defaults, formerDirectory: directory)
        addTeardownBlock { [directory] in try? FileManager.default.removeItem(at: directory!) }
    }

    func testSavedValueIsLoadedBack() {
        store.save(["a": 1], named: "doc")
        XCTAssertEqual(store.load([String: Int].self, named: "doc"), ["a": 1])
    }

    func testMissingDocumentIsNilAndLeavesNoBackup() {
        XCTAssertNil(store.load([String: Int].self, named: "doc"))
        XCTAssertNil(defaults.object(forKey: "doc.bak"))
    }

    /// The next save would otherwise replace a document that only could not be read (damaged, or a newer format).
    func testUnreadableDocumentIsKeptAsBackupBeforeItCanBeOverwritten() {
        let original = Data("{ not json".utf8)
        defaults.set(original, forKey: "doc")

        XCTAssertNil(store.load([String: Int].self, named: "doc"))
        store.save(["a": 1], named: "doc")

        XCTAssertEqual(defaults.data(forKey: "doc.bak"), original)
        XCTAssertEqual(store.load([String: Int].self, named: "doc"), ["a": 1])
    }

    func testADocumentOfAnEarlierVersionIsCarriedOverAndItsFileRemovedWithTheEmptyFolder() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data(#"{"a":1}"#.utf8).write(to: directory.appendingPathComponent("doc.json"))

        XCTAssertEqual(store.load([String: Int].self, named: "doc"), ["a": 1])
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.path))
        XCTAssertEqual(store.load([String: Int].self, named: "doc"), ["a": 1])
    }

    func testTheFolderOfAnEarlierVersionStaysWhileSomethingElseIsInIt() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data(#"{"a":1}"#.utf8).write(to: directory.appendingPathComponent("doc.json"))
        try Data().write(to: directory.appendingPathComponent("other"))

        XCTAssertEqual(store.load([String: Int].self, named: "doc"), ["a": 1])
        XCTAssertTrue(FileManager.default.fileExists(atPath: directory.appendingPathComponent("other").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.appendingPathComponent("doc.json").path))
    }

    func testAFileOfAnEarlierVersionDoesNotReplaceWhatIsKeptAlready() throws {
        store.save(["a": 2], named: "doc")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data(#"{"a":1}"#.utf8).write(to: directory.appendingPathComponent("doc.json"))

        XCTAssertEqual(store.load([String: Int].self, named: "doc"), ["a": 2])
    }
}
