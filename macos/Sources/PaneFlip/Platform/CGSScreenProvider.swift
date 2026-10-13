import AppKit

// Undocumented CoreGraphics Services calls: which desktop (Space) a display or window is on.
@_silgen_name("CGSMainConnectionID")
private func CGSMainConnectionID() -> Int32

@_silgen_name("CGSManagedDisplayGetCurrentSpace")
private func CGSManagedDisplayGetCurrentSpace(_ cid: Int32, _ displayUUID: CFString) -> UInt64

@_silgen_name("CGSCopySpacesForWindows")
private func CGSCopySpacesForWindows(_ cid: Int32, _ mask: Int32, _ wids: CFArray) -> CFArray?

final class CGSScreenProvider: ScreenProviding {
    private var primaryHeight: CGFloat { NSScreen.screens.first?.frame.height ?? 0 }

    func flip(_ r: CGRect) -> CGRect {
        CGRect(x: r.minX, y: primaryHeight - r.maxY, width: r.width, height: r.height)
    }

    var pointerCocoa: CGPoint { NSEvent.mouseLocation }

    var pointerAX: CGPoint {
        let m = NSEvent.mouseLocation
        return CGPoint(x: m.x, y: primaryHeight - m.y)
    }

    var menuBarThickness: CGFloat { NSStatusBar.system.thickness }

    /// While either is open the window manager keeps a full-screen shield window at layer 19. Its name is not
    /// used: other apps' window names are only readable with the Screen Recording permission.
    var isMissionControlActive: Bool {
        guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] else { return false }
        return list.contains {
            ($0[kCGWindowOwnerName as String] as? String) == "WindowManager" && ($0[kCGWindowLayer as String] as? Int) == 19
        }
    }

    func screens() -> [ScreenInfo] {
        let conn = CGSMainConnectionID()
        return NSScreen.screens.map { s in
            let uuid = displayUUID(s)
            let space = CGSManagedDisplayGetCurrentSpace(conn, uuid as CFString)
            return ScreenInfo(key: "\(uuid)|\(space)", name: s.localizedName, size: s.frame.size,
                              cocoaFrame: s.frame, cocoaVisibleFrame: s.visibleFrame, axVisible: flip(s.visibleFrame))
        }
    }

    func currentSpaceIDs() -> Set<UInt64> {
        let conn = CGSMainConnectionID()
        return Set(NSScreen.screens.map { CGSManagedDisplayGetCurrentSpace(conn, displayUUID($0) as CFString) })
    }

    func spaces(ofWindow id: CGWindowID) -> Set<UInt64> {
        let list = CGSCopySpacesForWindows(CGSMainConnectionID(), 7, [NSNumber(value: id)] as CFArray) as? [NSNumber] ?? []
        return Set(list.map(\.uint64Value))
    }

    private func displayUUID(_ s: NSScreen) -> String {
        guard let num = s.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber,
              let cfUUID = CGDisplayCreateUUIDFromDisplayID(CGDirectDisplayID(num.uint32Value))?.takeRetainedValue(),
              let str = CFUUIDCreateString(nil, cfUUID) as String?
        else { return "unknown" }
        return str
    }
}
