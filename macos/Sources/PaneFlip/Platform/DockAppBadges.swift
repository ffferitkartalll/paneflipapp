import AppKit
import ApplicationServices

/// Reads the badges from the Dock's own icons (`AXStatusLabel`), the only place the system keeps them.
final class DockAppBadges: AppBadging {
    func badges() -> [String: String] {
        guard let dock = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first else { return [:] }
        let root = AXUIElementCreateApplication(dock.processIdentifier)
        AXUIElementSetMessagingTimeout(root, 0.3)
        var children: CFTypeRef?
        guard AXUIElementCopyAttributeValue(root, kAXChildrenAttribute as CFString, &children) == .success,
              let list = (children as? [AXUIElement])?.first(where: { string($0, kAXRoleAttribute) == kAXListRole }),
              AXUIElementCopyAttributeValue(list, kAXChildrenAttribute as CFString, &children) == .success,
              let items = children as? [AXUIElement] else { return [:] }
        var result: [String: String] = [:]
        for item in items {
            guard let label = string(item, "AXStatusLabel"), !label.isEmpty else { continue }
            var url: CFTypeRef?
            guard AXUIElementCopyAttributeValue(item, kAXURLAttribute as CFString, &url) == .success, let bundleID = (url as? URL).flatMap({ Bundle(url: $0)?.bundleIdentifier }) else { continue }
            result[bundleID] = label
        }
        return result
    }

    private func string(_ element: AXUIElement, _ attribute: String) -> String? {
        var value: CFTypeRef?
        return AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success ? value as? String : nil
    }
}
