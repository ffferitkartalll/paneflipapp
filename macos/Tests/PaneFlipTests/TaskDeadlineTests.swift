import XCTest

final class TaskDeadlineTests: XCTestCase {
    func testATaskThatNeverEndsDoesNotHoldTheCaller() async {
        let started = Date()
        await TaskDeadline.wait(for: Task { try? await Task.sleep(for: .seconds(30)) }, seconds: 0.2)
        XCTAssertLessThan(Date().timeIntervalSince(started), 5)
    }

    func testATaskThatEndsReturnsAtOnce() async {
        let started = Date()
        await TaskDeadline.wait(for: Task {}, seconds: 30)
        XCTAssertLessThan(Date().timeIntervalSince(started), 5)
    }
}
