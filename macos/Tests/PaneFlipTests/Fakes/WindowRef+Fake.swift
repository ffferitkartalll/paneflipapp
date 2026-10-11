import ApplicationServices

extension WindowRef {
    /// A window handle for tests: the element is a plain application element, nothing is ever sent to it.
    static func fake(_ id: CGWindowID, pid: pid_t = 100) -> WindowRef {
        WindowRef(id: id, pid: pid, element: AXUIElementCreateApplication(pid))
    }
}
