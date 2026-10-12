import XCTest

final class SVGArcFlagsTests: XCTestCase {
    func testTheFlagsOfAnArcAreWrittenApart() {
        XCTAssertEqual(SVGArcFlags.normalizedPath("a.077.077 0 00-.0785.0371"), "a .077 .077 0 0 0 -.0785 .0371")
    }

    func testFlagsFollowedByANumberWithoutASeparator() {
        XCTAssertEqual(SVGArcFlags.normalizedPath("A2 2 0 1 0 5 5"), "A 2 2 0 1 0 5 5")
        XCTAssertEqual(SVGArcFlags.normalizedPath("a1 1 0 011 1"), "a 1 1 0 0 1 1 1")
    }

    func testRepeatedArcsKeepCountingTheirArguments() {
        XCTAssertEqual(SVGArcFlags.normalizedPath("a1 1 0 00 1 1 2 2 0 11 3 3"), "a 1 1 0 0 0 1 1 2 2 0 1 1 3 3")
    }

    func testOtherCommandsKeepTheirNumbers() {
        XCTAssertEqual(SVGArcFlags.normalizedPath("M1.5.5L2-3z"), "M 1.5 .5 L 2 -3 z")
    }

    func testOnlyThePathDataOfAnSVGChanges() {
        let svg = #"<svg viewBox="0 0 24 24"><path d="M0 0a1 1 0 00 1 1"/></svg>"#
        XCTAssertEqual(SVGArcFlags.normalized(svg), #"<svg viewBox="0 0 24 24"><path d="M 0 0 a 1 1 0 0 0 1 1"/></svg>"#)
    }
}
