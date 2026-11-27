import CoreGraphics
import Testing
@testable import PaneFlipCore

struct WheelStepsTests {
    @Test func aClickIsOneStepAtItsFirstMove() {
        var steps = WheelSteps()
        // A slow click of a driver's stream: about 400 points in small events, 7 to 30 ms apart.
        var taken = 0, time = 10.0
        for points in [1, 2, 4, 10, 16, 22, 21, 27, 21, 13, 21, 27, 21, 14, 20, 14, 20, 28, 14, 20] {
            taken += steps.add(CGFloat(-points), at: time)
            time += 0.012
        }
        #expect(taken == -1)
    }

    @Test func aPauseBeginsANewClick() {
        var steps = WheelSteps()
        #expect(steps.add(-3, at: 1.0) == -1)
        #expect(steps.add(-3, at: 1.05) == 0)
        #expect(steps.add(-3, at: 1.05 + WheelSteps.idle + 0.01) == -1)
    }

    @Test func aLongFlickGivesMoreSteps() {
        var steps = WheelSteps()
        var taken = 0, time = 5.0
        for _ in 0..<40 {
            taken += steps.add(100, at: time)
            time += 0.007
        }
        // 4000 points: the first move, then one for every 800.
        #expect(taken == 1 + 4)
    }

    @Test func turningBackStepsBackAtOnce() {
        var steps = WheelSteps()
        #expect(steps.add(50, at: 1.0) == 1)
        #expect(steps.add(-5, at: 1.01) == -1)
        #expect(steps.add(0, at: 1.02) == 0)
    }
}
