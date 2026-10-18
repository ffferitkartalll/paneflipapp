import XCTest
import PaneFlipCore

@MainActor
final class UpdatesModelTests: XCTestCase {
    private let checker = FakeReleaseChecker()

    private func model(version: String = "1.0", homebrew: Bool = false) -> UpdatesModel {
        UpdatesModel(currentVersion: version, checker: checker, installSource: FakeInstallSource(isHomebrew: homebrew))
    }

    func testANewerReleaseIsOffered() async {
        let model = model()
        XCTAssertEqual(model.state, .idle)
        await model.check()
        XCTAssertEqual(model.state, .available(checker.release!))
    }

    func testTheSameOrAnOlderReleaseMeansUpToDate() async {
        let same = model(version: "1.1")
        await same.check()
        XCTAssertEqual(same.state, .upToDate)
        let newer = model(version: "2.0")
        await newer.check()
        XCTAssertEqual(newer.state, .upToDate)
    }

    func testAFailedCheckSaysSoAndCanBeTriedAgain() async {
        checker.release = nil
        let model = model()
        await model.check()
        XCTAssertEqual(model.state, .failed)
        checker.release = ReleaseInfo(version: AppVersion("1.0")!, page: URL(string: "https://example.com")!)
        await model.check()
        XCTAssertEqual(model.state, .upToDate)
    }

    func testTheInstallSourceIsRemembered() {
        XCTAssertTrue(model(homebrew: true).installedWithHomebrew)
        XCTAssertFalse(model().installedWithHomebrew)
    }
}
