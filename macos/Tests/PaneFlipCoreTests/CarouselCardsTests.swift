import XCTest
@testable import PaneFlipCore

final class CarouselCardsTests: XCTestCase {
    func testTheOthersKeepTheWidthOfTheFrameWhileTheyFit() {
        let cards = CarouselCards(count: 3, wide: 100, fit: 500)
        XCTAssertEqual(cards.other(front: 1), 100)
        XCTAssertEqual(cards.centres(at: 1, other: 100), [-100, 0, 100])
    }

    func testTheOthersShareTheRoomOnTheSideWithMostOfThem() {
        let cards = CarouselCards(count: 6, wide: 100, fit: 400)   // 150 on each side of the front card
        XCTAssertEqual(cards.other(front: 0), 30, "five on the right: 150 / 5")
        XCTAssertEqual(cards.other(front: 2), 50, "three on the right, two on the left: the side with most decides")
        XCTAssertEqual(cards.other(front: 5), 30)
    }

    func testAllCardsStayWithinTheRoom() {
        let cards = CarouselCards(count: 7, wide: 100, fit: 500)
        for front in 0 ..< 7 {
            let other = cards.other(front: front)
            let centres = cards.centres(at: CGFloat(front), other: other)
            let widths = (0 ..< 7).map { cards.width(of: $0, at: CGFloat(front), other: other) }
            XCTAssertLessThanOrEqual(centres.last! + widths.last! / 2, 250 + 0.001)
            XCTAssertGreaterThanOrEqual(centres.first! - widths.first! / 2, -250 - 0.001)
        }
    }

    func testTheRowMovesSmoothlyBetweenTwoCards() {
        let cards = CarouselCards(count: 4, wide: 100, fit: 1000)
        XCTAssertEqual(cards.width(of: 1, at: 1.5, other: 20), 60)
        XCTAssertEqual(cards.centres(at: 1.5, other: 20), [-70, -30, 30, 70])
    }

    func testWithNoCardInFrontTheCardsShareTheRoomAndAreCentred() {
        let cards = CarouselCards(count: 4, wide: 100, fit: 200)
        XCTAssertEqual(cards.other(front: nil), 50)
        XCTAssertEqual(cards.centres(at: nil, other: 50), [-75, -25, 25, 75])
    }

    func testAClickFindsTheCardUnderIt() {
        let cards = CarouselCards(count: 4, wide: 100, fit: 1000)
        XCTAssertEqual(cards.card(atX: 0, at: 1, other: 100), 1)
        XCTAssertEqual(cards.card(atX: 150, at: 1, other: 100), 2)
        XCTAssertNil(cards.card(atX: 900, at: 1, other: 100))
    }
}
