import CoreGraphics

final class FakeScreens: ScreenProviding {
    var current: Set<UInt64> = [1]
    var spacesByWindow: [CGWindowID: Set<UInt64>] = [:]
    var pointerAX = CGPoint.zero
    var pointerCocoa = CGPoint.zero
    var menuBarThickness: CGFloat = 24

    var infos: [ScreenInfo] = []

    func screens() -> [ScreenInfo] { infos }
    func currentSpaceIDs() -> Set<UInt64> { current }
    func spaces(ofWindow id: CGWindowID) -> Set<UInt64> { spacesByWindow[id] ?? [] }
    func flip(_ rect: CGRect) -> CGRect { rect }
}
