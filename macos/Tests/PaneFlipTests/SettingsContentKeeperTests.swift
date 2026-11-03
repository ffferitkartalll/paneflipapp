import AppKit
import XCTest

@MainActor
final class SettingsContentKeeperTests: XCTestCase {
    func testAClosedSettingsWindowLetsGoOfItsContentAndGetsItBack() {
        let keeper = SettingsContentKeeper()
        keeper.start()
        let window = NSWindow(contentRect: .init(x: 0, y: 0, width: 100, height: 100), styleMask: [.titled, .closable], backing: .buffered, defer: true)
        window.isReleasedWhenClosed = false
        window.identifier = SettingsContentKeeper.windowIdentifier
        let content = NSView()
        window.contentView = content

        NotificationCenter.default.post(name: NSWindow.willCloseNotification, object: window)
        let released = expectation(description: "content let go")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { released.fulfill() }
        wait(for: [released], timeout: 2)
        XCTAssertNotIdentical(window.contentView, content)

        NotificationCenter.default.post(name: NSWindow.didBecomeKeyNotification, object: window)
        XCTAssertIdentical(window.contentView, content)
    }
}
