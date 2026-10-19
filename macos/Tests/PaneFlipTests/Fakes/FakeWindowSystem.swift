import CoreGraphics

/// A window system the tests can arrange: which windows exist, which are visible, what the apps list.
final class FakeWindowSystem: WindowSystem {
    var isTrusted = true
    var focused: WindowRef?
    var all: Set<CGWindowID> = []
    var onScreen: Set<CGWindowID> = []
    var frontToBack: [CGWindowID] = []
    var minimized: Set<CGWindowID> = []
    var titles: [CGWindowID: String] = [:]
    var windowsByPID: [pid_t: [WindowRef]] = [:]
    private(set) var frames: [CGWindowID: CGRect] = [:]
    private(set) var setCalls = 0
    private(set) var positionCalls = 0
    private(set) var raised: [CGWindowID] = []

    func focusedWindow() -> WindowRef? { focused }
    func windowUnderPointer() -> (ref: WindowRef, frame: CGRect)? { nil }
    func windows(ofApp pid: pid_t) -> [WindowRef] { windowsByPID[pid] ?? [] }
    func frame(of ref: WindowRef) -> CGRect? { frames[ref.id] }
    func setFrame(_ rect: CGRect, of ref: WindowRef) { frames[ref.id] = rect; setCalls += 1 }
    /// A window changed by something else than the code under test.
    func setFrameDirectly(_ rect: CGRect, of id: CGWindowID) { frames[id] = rect }

    func setPosition(_ point: CGPoint, of ref: WindowRef) {
        frames[ref.id] = CGRect(origin: point, size: frames[ref.id]?.size ?? .zero)
        positionCalls += 1
    }
    func title(of ref: WindowRef) -> String? { titles[ref.id] }
    func isMinimized(_ ref: WindowRef) -> Bool { minimized.contains(ref.id) }
    func raise(_ ref: WindowRef) { raised.append(ref.id) }
    func windowSets() -> (all: Set<CGWindowID>, onScreen: Set<CGWindowID>) { (all, onScreen) }
    func windowIDsFrontToBack() -> [CGWindowID] { frontToBack }
}
