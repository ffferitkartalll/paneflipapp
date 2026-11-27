import XCTest
import PaneFlipCore

final class WheelIdleTests: XCTestCase {
    func testItCallsBackOnceWhenTheEventsStop() {
        let ended = expectation(description: "idle")
        var calls = 0
        let idle = WheelIdle { calls += 1; ended.fulfill() }
        // Events every 50 ms for a third of a second: the stream goes on, so nothing ends before the last one.
        for i in 0..<7 { DispatchQueue.main.asyncAfter(deadline: .now() + 0.05 * Double(i)) { idle.touch() } }
        wait(for: [ended], timeout: 2)
        XCTAssertEqual(calls, 1)
    }
}
