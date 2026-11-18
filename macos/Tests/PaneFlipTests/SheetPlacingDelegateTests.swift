import AppKit
import XCTest

final class SheetPlacingDelegateTests: XCTestCase {
    private func window(_ width: CGFloat, _ height: CGFloat) -> NSWindow {
        NSWindow(contentRect: NSRect(x: 0, y: 0, width: width, height: height), styleMask: [.titled], backing: .buffered, defer: false)
    }

    func testASheetOverTheSheetIsPutTheInsetLowerAndTheWindowsOwnDelegateComesBackWhenTheSheetHasGone() {
        let main = window(720, 700)
        let own = FakeWindowDelegate()
        main.delegate = own
        let under = window(640, 600)
        main.beginSheet(under)
        SheetPlacingDelegate.install(on: main, under: under, inset: 20)
        let place = NSRect(x: 0, y: 620, width: 720, height: 0)

        XCTAssertEqual(main.delegate?.window?(main, willPositionSheet: window(600, 560), using: place), place.offsetBy(dx: 0, dy: -20), "a sheet over the sheet: lower")
        XCTAssertEqual(main.delegate?.window?(main, willPositionSheet: under, using: place), place, "the sheet under stays where the window puts it")
        XCTAssertEqual(main.delegate?.windowShouldClose?(main), false, "the rest goes to the window's own delegate")

        main.endSheet(under)
        XCTAssertTrue(main.delegate === own)
        XCTAssertEqual(own.endedSheets, 1, "the window's own delegate hears of the end once")
    }

    func testTheStandInKeepsItselfWhileTheSheetIsOpenAndLetsGoWithIt() {
        let main = window(720, 700)
        let own = FakeWindowDelegate()
        main.delegate = own
        let under = window(640, 600)
        main.beginSheet(under)
        weak var standIn: NSObject?
        autoreleasepool {
            SheetPlacingDelegate.install(on: main, under: under, inset: 20)
            standIn = main.delegate as? NSObject
        }
        XCTAssertNotNil(standIn, "a window holds its delegate weakly: the stand-in keeps itself")

        autoreleasepool { main.endSheet(under) }
        XCTAssertTrue(main.delegate === own)
        XCTAssertNil(standIn, "and lets itself go with the sheet")
    }

    func testNothingStandsInForASheetThatIsNotAttachedAndASecondInstallChangesNothing() {
        let main = window(720, 700)
        let own = FakeWindowDelegate()
        main.delegate = own
        let under = window(640, 600)

        SheetPlacingDelegate.install(on: main, under: under, inset: 20)
        XCTAssertTrue(main.delegate === own, "not attached: nothing to stand in for")

        main.beginSheet(under)
        autoreleasepool {
            SheetPlacingDelegate.install(on: main, under: under, inset: 20)
            SheetPlacingDelegate.install(on: main, under: under, inset: 20)
        }
        autoreleasepool { main.endSheet(under) }
        XCTAssertTrue(main.delegate === own)
        XCTAssertEqual(own.endedSheets, 1)
    }
}
