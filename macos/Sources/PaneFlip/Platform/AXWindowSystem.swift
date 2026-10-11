import AppKit
import ApplicationServices

/// Undocumented but long-stable: maps an accessibility window to its CGWindowID.
@_silgen_name("_AXUIElementGetWindow")
private func _AXUIElementGetWindow(_ element: AXUIElement, _ id: UnsafeMutablePointer<CGWindowID>) -> AXError

final class AXWindowSystem: WindowSystem {
    private let screens: ScreenProviding

    init(screens: ScreenProviding) { self.screens = screens }

    var isTrusted: Bool { AXIsProcessTrusted() }

    // MARK: Finding windows

    func focusedWindow() -> WindowRef? {
        guard let app = NSWorkspace.shared.frontmostApplication,
              app.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return nil }
        var v: CFTypeRef?
        guard AXUIElementCopyAttributeValue(AXUIElementCreateApplication(app.processIdentifier),
                                            kAXFocusedWindowAttribute as CFString, &v) == .success,
              let win = v else { return nil }
        return makeRef(win as! AXUIElement, pid: app.processIdentifier)
    }

    func windowUnderPointer() -> (ref: WindowRef, frame: CGRect)? {
        let p = screens.pointerAX
        var el: AXUIElement?
        guard AXUIElementCopyElementAtPosition(AXUIElementCreateSystemWide(), Float(p.x), Float(p.y), &el) == .success,
              let el else { return nil }
        var v: CFTypeRef?
        var win = el
        if AXUIElementCopyAttributeValue(el, kAXWindowAttribute as CFString, &v) == .success, let w = v { win = w as! AXUIElement }
        var pid: pid_t = 0
        guard AXUIElementGetPid(win, &pid) == .success, pid != ProcessInfo.processInfo.processIdentifier,
              let ref = makeRef(win, pid: pid), let f = frame(win) else { return nil }
        return (ref, f)
    }

    func windows(ofApp pid: pid_t) -> [WindowRef] {
        var v: CFTypeRef?
        guard AXUIElementCopyAttributeValue(AXUIElementCreateApplication(pid), kAXWindowsAttribute as CFString, &v) == .success,
              let list = v as? [AXUIElement] else { return [] }
        return list.compactMap { el in
            var subrole: CFTypeRef?
            guard AXUIElementCopyAttributeValue(el, kAXSubroleAttribute as CFString, &subrole) == .success,
                  (subrole as? String) == "AXStandardWindow", !minimized(el) else { return nil }
            return makeRef(el, pid: pid)
        }
    }

    // MARK: Reading and moving

    func frame(of ref: WindowRef) -> CGRect? { frame(ref.element) }

    func setFrame(_ rect: CGRect, of ref: WindowRef) {
        var p = rect.origin, s = rect.size
        // Size → position → size: the first size lets a window near a screen edge move, the last corrects what the move changed.
        if let sv = AXValueCreate(.cgSize, &s) { AXUIElementSetAttributeValue(ref.element, kAXSizeAttribute as CFString, sv) }
        if let pv = AXValueCreate(.cgPoint, &p) { AXUIElementSetAttributeValue(ref.element, kAXPositionAttribute as CFString, pv) }
        if let sv = AXValueCreate(.cgSize, &s) { AXUIElementSetAttributeValue(ref.element, kAXSizeAttribute as CFString, sv) }
    }

    func title(of ref: WindowRef) -> String? {
        var v: CFTypeRef?
        guard AXUIElementCopyAttributeValue(ref.element, kAXTitleAttribute as CFString, &v) == .success,
              let s = v as? String, !s.isEmpty else { return nil }
        return s
    }

    func isMinimized(_ ref: WindowRef) -> Bool { minimized(ref.element) }

    func raise(_ ref: WindowRef) {
        AXUIElementPerformAction(ref.element, kAXRaiseAction as CFString)
        AXUIElementSetAttributeValue(ref.element, kAXMainAttribute as CFString, kCFBooleanTrue)
        // Making the owning app frontmost through AX works while PaneFlip itself is not the active app.
        AXUIElementSetAttributeValue(AXUIElementCreateApplication(ref.pid), kAXFrontmostAttribute as CFString, kCFBooleanTrue)
    }

    // MARK: System window list

    func allWindowIDs() -> Set<CGWindowID> { windowNumbers(.optionAll) }
    func onScreenWindowIDs() -> Set<CGWindowID> { windowNumbers(.optionOnScreenOnly) }

    private func windowNumbers(_ option: CGWindowListOption) -> Set<CGWindowID> {
        guard let list = CGWindowListCopyWindowInfo([option], kCGNullWindowID) as? [[String: Any]] else { return [] }
        return Set(list.compactMap { ($0[kCGWindowNumber as String] as? NSNumber)?.uint32Value })
    }

    // MARK: Helpers

    private func makeRef(_ el: AXUIElement, pid: pid_t) -> WindowRef? {
        var id: CGWindowID = 0
        guard _AXUIElementGetWindow(el, &id) == .success, id != 0 else { return nil }
        return WindowRef(id: id, pid: pid, element: el)
    }

    private func minimized(_ el: AXUIElement) -> Bool {
        var v: CFTypeRef?
        return AXUIElementCopyAttributeValue(el, kAXMinimizedAttribute as CFString, &v) == .success && (v as? Bool) == true
    }

    private func frame(_ el: AXUIElement) -> CGRect? {
        var pv: CFTypeRef?, sv: CFTypeRef?
        var p = CGPoint.zero, s = CGSize.zero
        guard AXUIElementCopyAttributeValue(el, kAXPositionAttribute as CFString, &pv) == .success,
              AXUIElementCopyAttributeValue(el, kAXSizeAttribute as CFString, &sv) == .success,
              AXValueGetValue(pv as! AXValue, .cgPoint, &p),
              AXValueGetValue(sv as! AXValue, .cgSize, &s) else { return nil }
        return CGRect(origin: p, size: s)
    }
}
