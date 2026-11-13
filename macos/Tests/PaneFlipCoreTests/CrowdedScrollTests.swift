import Testing
@testable import PaneFlipCore

struct CrowdedScrollTests {
    @Test func twoFingersScrollAsAlways() {
        var scroll = CrowdedScroll()
        #expect([128, 1, 2, 4, 0].map { scroll.take(crowded: false, phase: $0) } == [.pass, .pass, .pass, .pass, .pass])
    }

    @Test func aThirdFingerEndsTheScrollTheAppSawAndTakesTheRestWithItsGlide() {
        var scroll = CrowdedScroll()
        #expect(scroll.take(crowded: false, phase: 1) == .pass)
        #expect(scroll.take(crowded: true, phase: 2) == .end)
        #expect(scroll.take(crowded: true, phase: 2) == .swallow)
        // The fingers are up: the end and the glide still belong to that swipe.
        #expect(scroll.take(crowded: false, phase: 4) == .swallow)
        #expect(scroll.take(crowded: false, phase: 0) == .swallow)
        // The next scroll with two fingers is the app's again.
        #expect(scroll.take(crowded: false, phase: 1) == .pass)
        #expect(scroll.take(crowded: false, phase: 2) == .pass)
    }

    @Test func aScrollThatBeginsWithThreeFingersDownNeverReachesTheApp() {
        var scroll = CrowdedScroll()
        #expect([1, 2, 4].map { scroll.take(crowded: true, phase: $0) } == [.swallow, .swallow, .swallow])
    }
}
