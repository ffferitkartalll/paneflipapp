import XCTest
import PaneFlipCore

@MainActor
final class UpdatesModelTests: XCTestCase {
    private let checker = FakeReleaseChecker()

    private let installer = FakeUpdateInstaller()

    private func model(version: String = "1.0") -> UpdatesModel {
        UpdatesModel(currentVersion: version, checker: checker, installer: installer)
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

    func testTheFoundReleaseIsInstalledFromTheModel() async {
        let model = model()
        await model.install()
        XCTAssertTrue(installer.installed.isEmpty, "nothing is installed before a release was found")
        await model.check()
        await model.install()
        XCTAssertEqual(installer.installed, [checker.release!])
        XCTAssertEqual(model.state, .installing(checker.release!), "the app quits by itself when it worked")
    }

    func testAFailedInstallOffersTheReleasePage() async {
        installer.fails = true
        let model = model()
        await model.check()
        await model.install()
        XCTAssertEqual(model.state, .installFailed(checker.release!))
    }

    func testTheDiskImageLiesBesideTheReleasePage() {
        let release = ReleaseInfo(version: AppVersion("1.1")!, page: URL(string: "https://github.com/o/r/releases/tag/v1.1")!)
        XCTAssertEqual(release.diskImage.absoluteString, "https://github.com/o/r/releases/download/v1.1/PaneFlip-1.1.dmg")
    }
}
