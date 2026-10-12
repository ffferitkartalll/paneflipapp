import XCTest
import CoreGraphics

final class ScreenInfoTests: XCTestCase {
    private func screen(visible: CGRect, key: String = "display|1") -> ScreenInfo {
        let frame = CGRect(x: 0, y: 0, width: 1000, height: 600)
        return ScreenInfo(key: key, name: "Display", size: frame.size, cocoaFrame: frame, cocoaVisibleFrame: visible, axVisible: visible)
    }

    func testTheSignatureChangesWhenTheUsableAreaChanges() {
        let withDock = screen(visible: CGRect(x: 0, y: 60, width: 1000, height: 516))
        let withoutDock = screen(visible: CGRect(x: 0, y: 0, width: 1000, height: 576))
        XCTAssertNotEqual(withDock.layoutSignature, withoutDock.layoutSignature)
    }

    func testTheSignatureChangesWithTheDesktop() {
        let area = CGRect(x: 0, y: 0, width: 1000, height: 576)
        XCTAssertNotEqual(screen(visible: area, key: "display|1").layoutSignature, screen(visible: area, key: "display|2").layoutSignature)
    }

    func testTheSignatureStaysWhenNothingChanged() {
        let area = CGRect(x: 0, y: 0, width: 1000, height: 576)
        XCTAssertEqual(screen(visible: area).layoutSignature, screen(visible: area).layoutSignature)
    }
}
