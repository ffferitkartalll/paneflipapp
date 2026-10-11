import CoreGraphics

/// A window system the tests can arrange: which windows exist, which are visible, what the apps list.
final class FakeWindowSystem: WindowSystem {
    var isTrusted = true
    var all: Set<CGWindowID> = []
    var onScreen: Set<CGWindowID> = []
    var frontToBack: [CGWindowID] = []
    var minimized: Set<CGWindowID> = []
    var titles: [CGWindowID: String] = [:]
    var windowsByPID: [pid_t: [WindowRef]] = [:]
    private(set) var frames: [CGWindowID: CGRect] = [:]
    private(set) var raised: [CGWindowID] = []

    func focusedWindow() -> WindowRef? { nil }
    func windowUnderPointer() -> (ref: WindowRef, frame: CGRect)? { nil }
    func windows(ofApp pid: pid_t) -> [WindowRef] { windowsByPID[pid] ?? [] }
    func frame(of ref: WindowRef) -> CGRect? { frames[ref.id] }
    func setFrame(_ rect: CGRect, of ref: WindowRef) { frames[ref.id] = rect }
    func title(of ref: WindowRef) -> String? { titles[ref.id] }
    func isMinimized(_ ref: WindowRef) -> Bool { minimized.contains(ref.id) }
    func raise(_ ref: WindowRef) { raised.append(ref.id) }
    func allWindowIDs() -> Set<CGWindowID> { all }
    func onScreenWindowIDs() -> Set<CGWindowID> { onScreen }
    func windowIDsFrontToBack() -> [CGWindowID] { frontToBack }
}
