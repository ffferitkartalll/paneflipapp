import XCTest
@testable import PaneFlipCore

final class CarouselCardsTests: XCTestCase {
    func testTheOthersKeepTheWidthOfTheFrame() {
        let cards = CarouselCards(count: 3, wide: 100)
        XCTAssertEqual(cards.other, 100)
        XCTAssertEqual(cards.centres(at: 1, other: cards.other), [-100, 0, 100])
    }

    func testTheRowGoesOnPastTheRoomWhateverTheNumberOfCards() {
        let cards = CarouselCards(count: 7, wide: 100)
        let centres = cards.centres(at: 0, other: cards.other)
        XCTAssertEqual(centres.first, 0)
        XCTAssertEqual(centres.last, 600)
    }

    func testTheRowMovesSmoothlyBetweenTwoCards() {
        let cards = CarouselCards(count: 4, wide: 100)
        XCTAssertEqual(cards.width(of: 1, at: 1.5, other: 20), 60)
        XCTAssertEqual(cards.centres(at: 1.5, other: 20), [-70, -30, 30, 70])
    }

    func testTheRowCanBeHeldOnAPlaceInsteadOfTheFrontCard() {
        let cards = CarouselCards(count: 3, wide: 100)
        XCTAssertEqual(cards.centres(at: 0, other: 100, focus: 1), [-100, 0, 100], "the card in front is first, the row stays where it was")
        XCTAssertEqual(cards.centres(at: 0, other: 100), [0, 100, 200])
    }

    func testWithNoCardInFrontTheCardsAreCentred() {
        let cards = CarouselCards(count: 4, wide: 100)
        XCTAssertEqual(cards.centres(at: nil, other: cards.other), [-150, -50, 50, 150])
    }

    func testAClickFindsTheCardUnderIt() {
        let cards = CarouselCards(count: 4, wide: 100)
        XCTAssertEqual(cards.card(atX: 0, at: 1, other: 100), 1)
        XCTAssertEqual(cards.card(atX: 150, at: 1, other: 100), 2)
        XCTAssertNil(cards.card(atX: 900, at: 1, other: 100))
    }
}
