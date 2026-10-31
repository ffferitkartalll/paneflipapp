import AppKit
import ColorSync
import PaneFlipCore

/// The hidden displays, made with the system's virtual display (a private interface, looked up at run time: where it is missing or fails there is no hidden
/// display, and the real display has no screens beyond its edges). One for each real display: as large as it, with its colours and its refresh rate, at its lower
/// right corner. A window that waits there keeps its colours, its size and its frame rate when it moves to the real display and back, so it is not drawn again.
final class VirtualParkingDisplay: ParkingDisplaying {
    private final class Hidden {
        let display: NSObject
        let id: CGDirectDisplayID
        /// The size it was asked to have: the size of the real display, so that no window is made smaller to fit it while it waits there (an app keeps a window
        /// inside the display it is on, and the window is then laid out again and photographed too small).
        let size: CGSize
        var coloursOf: CGDirectDisplayID?

        init(display: NSObject, id: CGDirectDisplayID, size: CGSize) {
            self.display = display
            self.id = id
            self.size = size
        }
    }

    /// Each real display's hidden display, by the real display's number.
    private var hidden: [CGDirectDisplayID: Hidden] = [:]

    var displayIDs: Set<CGDirectDisplayID> { Set(hidden.values.map(\.id)) }

    func area(forDisplay id: CGDirectDisplayID) -> CGRect? {
        guard let entry = hidden[id], CGDisplayIsActive(entry.id) != 0 else { return nil }
        let bounds = CGDisplayBounds(entry.id)
        return bounds.width >= entry.size.width && bounds.height >= entry.size.height ? bounds : nil
    }

    func update(enabled: Bool, besides displays: [(id: CGDirectDisplayID, frame: CGRect)]) {
        guard enabled else { return hidden.removeAll() }
        // The ones whose real display went, which the system took away (a wake from sleep, say), or whose real display changed its size: made again.
        let sizes = Dictionary(displays.map { ($0.id, $0.frame.size) }, uniquingKeysWith: { first, _ in first })
        hidden = hidden.filter { id, entry in sizes[id] == entry.size && CGDisplayIsActive(entry.id) != 0 }
        var taken = displays.map(\.frame)
        for display in displays {
            // At the lower right corner, where nothing lies (and no other hidden display): else this display has none.
            guard let area = Parking.hiddenArea(for: display.frame, avoiding: taken.filter { $0 != display.frame }) else { hidden[display.id] = nil; continue }
            taken.append(area)
            if hidden[display.id] == nil { hidden[display.id] = make(for: display.id, size: display.frame.size) }
            guard let entry = hidden[display.id] else { continue }
            matchColours(of: entry, to: display.id)
            guard CGDisplayBounds(entry.id).origin != area.origin else { continue }
            var config: CGDisplayConfigRef?
            guard CGBeginDisplayConfiguration(&config) == .success else { continue }
            CGConfigureDisplayOrigin(config, entry.id, Int32(area.origin.x), Int32(area.origin.y))
            CGCompleteDisplayConfiguration(config, .forSession)
        }
        // Those of displays that are gone are already dropped by the filter above.
    }

    /// Gives the hidden display the colour profile of its real display, so that a window that moves between them keeps its colours and is not drawn again.
    private func matchColours(of entry: Hidden, to real: CGDirectDisplayID) {
        guard entry.coloursOf != real,
              let icc = CGDisplayCopyColorSpace(real).copyICCData() as Data?,
              let uuid = CGDisplayCreateUUIDFromDisplayID(entry.id)?.takeRetainedValue(),
              let device = kColorSyncDisplayDeviceClass, let key = kColorSyncDeviceDefaultProfileID else { return }
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("PaneFlip-parking-\(real).icc")
        guard (try? icc.write(to: file)) != nil,
              ColorSyncDeviceSetCustomProfiles(device.takeUnretainedValue(), uuid, [key.takeUnretainedValue(): file] as CFDictionary) else { return }
        entry.coloursOf = real
    }

    private func make(for real: CGDirectDisplayID, size: CGSize) -> Hidden? {
        func type(_ name: String) -> NSObject.Type? { NSClassFromString(name) as? NSObject.Type }
        guard let descriptorType = type("CGVirtualDisplayDescriptor"), let modeType = type("CGVirtualDisplayMode"),
              let settingsType = type("CGVirtualDisplaySettings"), let displayType = type("CGVirtualDisplay") else { return nil }
        let width = UInt32(size.width.rounded(.up)), height = UInt32(size.height.rounded(.up))
        // As fast as the real display: a slower display of the window server's own would hold the frames of the others back.
        let refreshRate = max(CGDisplayCopyDisplayMode(real)?.refreshRate ?? 60, 60)
        // With as many pixels to a point as the real display (a retina display has two): a window that changes the scale is drawn again.
        let scale = UInt32(max((Double(CGDisplayCopyDisplayMode(real)?.pixelWidth ?? 1) / max(CGDisplayBounds(real).width, 1)).rounded(), 1))
        let descriptor = descriptorType.init()
        descriptor.setValue(DispatchQueue.main, forKey: "queue")
        descriptor.setValue("PaneFlip", forKey: "name")
        descriptor.setValue(NSNumber(value: 0x7A11), forKey: "vendorID")
        // Told apart by the real display's number (the system keeps the modes of a model of display: two with one model would share them).
        descriptor.setValue(NSNumber(value: 0x1000 + real), forKey: "productID")
        descriptor.setValue(NSNumber(value: real), forKey: "serialNum")
        descriptor.setValue(NSNumber(value: width * scale), forKey: "maxPixelsWide")
        descriptor.setValue(NSNumber(value: height * scale), forKey: "maxPixelsHigh")
        descriptor.setValue(NSValue(size: NSSize(width: Double(width) / 4, height: Double(height) / 4)), forKey: "sizeInMillimeters")

        typealias InitMode = @convention(c) (AnyObject, Selector, UInt32, UInt32, Double) -> AnyObject
        let initMode = NSSelectorFromString("initWithWidth:height:refreshRate:")
        func mode(_ width: UInt32, _ height: UInt32) -> NSObject? {
            guard let blank = modeType.perform(NSSelectorFromString("alloc"))?.takeUnretainedValue() as? NSObject, blank.responds(to: initMode) else { return nil }
            return unsafeBitCast(blank.method(for: initMode), to: InitMode.self)(blank, initMode, width, height, refreshRate) as? NSObject
        }
        // At two pixels to a point the system wants the mode of the pixels beside the one of the points.
        let modes = (scale > 1 ? [mode(width * scale, height * scale), mode(width, height)] : [mode(width, height)]).compactMap { $0 }
        guard !modes.isEmpty else { return nil }
        let settings = settingsType.init()
        settings.setValue(NSNumber(value: scale > 1 ? 1 : 0), forKey: "hiDPI")
        settings.setValue(modes, forKey: "modes")

        // `alloc` hands its object on to `init`, which hands it to us: only the result is ours to release.
        guard let blank = displayType.perform(NSSelectorFromString("alloc"))?.takeUnretainedValue() as? NSObject,
              let made = blank.perform(NSSelectorFromString("initWithDescriptor:"), with: descriptor)?.takeRetainedValue() as? NSObject,
              made.perform(NSSelectorFromString("applySettings:"), with: settings) != nil,
              let id = (made.value(forKey: "displayID") as? NSNumber)?.uint32Value, id != 0 else { return nil }
        return Hidden(display: made, id: id, size: size)
    }
}
