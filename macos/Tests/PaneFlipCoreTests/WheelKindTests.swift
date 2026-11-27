import Testing
@testable import PaneFlipCore

struct WheelKindTests {
    @Test func aWheelThatClicksIsNotContinuous() {
        #expect(WheelKind(continuous: false, phase: 0, momentum: 0, mode: { nil }) == .notch)
    }

    @Test func fingersAndTheirGlideHaveTouchPhases() {
        #expect([1, 2, 4, 8].map { WheelKind(continuous: true, phase: $0, momentum: 0, mode: { .freeSpin }) } == Array(repeating: .fingers, count: 4))
        #expect(WheelKind(continuous: true, phase: 0, momentum: 2, mode: { .freeSpin }) == .fingers)
    }

    @Test func aSmoothedWheelIsFingersInFreeSpinAndAWheelOtherwise() {
        #expect(WheelKind(continuous: true, phase: 0, momentum: 0, mode: { .freeSpin }) == .freeSpin)
        #expect(WheelKind(continuous: true, phase: 0, momentum: 0, mode: { .ratchet }) == .smooth)
        // The mouse cannot say: a wheel.
        #expect(WheelKind(continuous: true, phase: 0, momentum: 0, mode: { nil }) == .smooth)
    }

    @Test func theMouseIsAskedOnlyForASmoothStream() {
        var asked = 0
        let mode: () -> WheelMode? = { asked += 1; return nil }
        _ = WheelKind(continuous: false, phase: 0, momentum: 0, mode: mode)
        _ = WheelKind(continuous: true, phase: 2, momentum: 0, mode: mode)
        #expect(asked == 0)
        _ = WheelKind(continuous: true, phase: 0, momentum: 0, mode: mode)
        #expect(asked == 1)
    }
}
