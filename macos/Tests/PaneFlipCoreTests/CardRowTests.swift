import CoreGraphics
import Testing
@testable import PaneFlipCore

struct CardRowTests {
    private let room: CGFloat = 600
    private func fits(_ widths: [CGFloat]) -> Bool { widths.reduce(0, +) <= room }

    @Test func cardsThatFitKeepTheirWidths() {
        #expect(CardRow.narrowed([100, 200, 250], narrowest: [50, 50, 50], fits: fits) == [100, 200, 250])
    }

    @Test func onlyTheWidestAreMadeNarrowerAndOnlyAsMuchAsTheyMust() {
        let widths = CardRow.narrowed([50, 50, 400, 400], narrowest: [40, 40, 40, 40], fits: fits)
        #expect(widths[0] == 50 && widths[1] == 50, "the narrow ones stay")
        #expect(abs(widths[2] - 250) < 0.01 && widths[2] == widths[3], "the widest share what is left")
    }

    @Test func noCardIsMadeNarrowerThanTheNarrowest() {
        #expect(CardRow.narrowed([50, 300, 300], narrowest: [290, 290, 290], fits: fits) == [50, 290, 290], "they do not fit even so")
        #expect(CardRow.narrowed([300, 300], narrowest: [100, 200], fits: { $0.reduce(0, +) <= 250 }) == [100, 200], "each keeps its own narrowest")
    }

    @Test func theLitCardStandsOnACardAndBetweenTwo() {
        let widths: [CGFloat] = [100, 50, 200]
        #expect(CardRow.lit(at: 0, widths: widths) == (0, 100))
        #expect(CardRow.lit(at: 1, widths: widths) == (100, 50))
        #expect(CardRow.lit(at: 1.5, widths: widths) == (125, 125), "half the way: its edges are half the way from one card's to the next's")
        #expect(CardRow.lit(at: 2, widths: widths) == (150, 200))
        #expect(CardRow.lit(at: 3, widths: widths) == (150, 200), "not past the last")
        #expect(CardRow.lit(at: -1, widths: widths) == (0, 100), "nor before the first")
    }

    @Test func theCardUnderAPointIsFound() {
        let widths: [CGFloat] = [100, 50, 200]
        #expect(CardRow.index(atX: 0, widths: widths) == 0)
        #expect(CardRow.index(atX: 99.5, widths: widths) == 0)
        #expect(CardRow.index(atX: 100, widths: widths) == 1, "an edge belongs to the card it begins")
        #expect(CardRow.index(atX: 349, widths: widths) == 2)
        #expect(CardRow.index(atX: 350, widths: widths) == nil, "past the last")
        #expect(CardRow.index(atX: -1, widths: widths) == nil, "before the first")
    }
}
