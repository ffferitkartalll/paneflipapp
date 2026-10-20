import CoreGraphics

final class FakeScreens: ScreenProviding {
    var current: Set<UInt64> = [1]
    var spacesByWindow: [CGWindowID: Set<UInt64>] = [:]
    var pointerAX = CGPoint.zero
    var pointerCocoa = CGPoint.zero
    var menuBarThickness: CGFloat = 24
    var isMissionControlActive = false

    var infos: [ScreenInfo] = []

    var frames: [CGRect] { infos.map(\.cocoaFrame) }
    private(set) var screensCalls = 0
    func screens() -> [ScreenInfo] { screensCalls += 1; return infos }
    func currentSpaceIDs() -> Set<UInt64> { current }
    func spaces(ofWindow id: CGWindowID) -> Set<UInt64> { spacesByWindow[id] ?? [] }
    func flip(_ rect: CGRect) -> CGRect { rect }
}
