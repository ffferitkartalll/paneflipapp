import AppKit

/// The round glass button beside the pill that hides it. A panel of its own, so the system control keeps its toolbar
/// to itself. Click-through and invisible until the pill is shown.
final class PillHideButton: NSPanel {
    static let size: CGFloat = 28
    static let gap: CGFloat = 6

    /// Where the button goes: right of the capsule, centred on it (Cocoa coordinates).
    static func frame(besideCapsule capsule: NSRect) -> NSRect {
        NSRect(x: capsule.maxX + gap, y: capsule.midY - size / 2, width: size, height: size)
    }

    /// The same place in top-left-origin coordinates, for hit testing.
    static func rect(besideCapsule capsule: CGRect) -> CGRect {
        CGRect(x: capsule.maxX + gap, y: capsule.midY - size / 2, width: size, height: size)
    }

    private let action: () -> Void

    init(action: @escaping () -> Void) {
        self.action = action
        super.init(contentRect: NSRect(x: 0, y: 0, width: Self.size, height: Self.size),
                   styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        level = .floating
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        alphaValue = 0
        ignoresMouseEvents = true
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]

        let button = NSButton(frame: NSRect(x: 0, y: 0, width: Self.size, height: Self.size))
        button.isBordered = false
        button.imagePosition = .imageOnly
        button.image = NSImage(systemSymbolName: "eye.slash", accessibilityDescription: String(localized: "Hide the pill"))
        button.toolTip = String(localized: "Hide the pill")
        button.target = self
        button.action = #selector(pressed)
        let glass = NSGlassEffectView(frame: NSRect(x: 0, y: 0, width: Self.size, height: Self.size))
        glass.cornerRadius = Self.size / 2
        glass.contentView = button
        contentView = glass
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    @objc private func pressed() { action() }
}
