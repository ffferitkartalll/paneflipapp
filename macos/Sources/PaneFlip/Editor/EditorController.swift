import AppKit
import PaneFlipCore
import SwiftUI

final class EditorController: LayoutEditing {
    private let repository: LayoutRepository
    private let layouts: LayoutManaging
    private let screens: ScreenProviding
    private let settings: AppSettings

    private var panel: NSPanel?
    private var monitor: Any?

    init(repository: LayoutRepository, layouts: LayoutManaging, screens: ScreenProviding, settings: AppSettings) {
        self.repository = repository
        self.layouts = layouts
        self.screens = screens
        self.settings = settings
    }

    var isShown: Bool { panel != nil }

    func toggleAtPointer() {
        if isShown { return hide() }
        let all = screens.screens()
        let pointer = screens.pointerCocoa
        guard let screen = all.first(where: { $0.cocoaFrame.contains(pointer) }) ?? all.first else { return }
        let layout = repository.activeLayout(for: screen.key) ?? layouts.addLayout(for: screen.key)
        edit(on: screen, layoutID: layout.id)
    }

    func edit(on screen: ScreenInfo, layoutID: UUID) {
        hide()
        guard let layout = repository.layout(id: layoutID, key: screen.key) else { return }
        let model = EditorModel(
            root: layout.root,
            onApply: { [layouts] root in layouts.updateLayout(key: screen.key, id: layoutID, root: root) },
            onClose: { [weak self] in self?.hide() })

        let frame = screen.cocoaVisibleFrame
        let p = EditorPanel(contentRect: frame, styleMask: [.borderless], backing: .buffered, defer: false)
        p.level = .statusBar
        p.backgroundColor = .black
        p.setFrame(frame, display: true)
        p.contentView = NSHostingView(rootView: EditorView(model: model, settings: settings))
        p.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        panel = p

        monitor = NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged, .keyDown]) { [weak model] event in
            if event.type == .flagsChanged { model?.shift = event.modifierFlags.contains(.shift) }
            else if event.keyCode == 53 { model?.close(); return nil }   // Esc
            return event
        }
    }

    private func hide() {
        if let m = monitor { NSEvent.removeMonitor(m) }
        monitor = nil
        panel?.orderOut(nil)
        panel = nil
    }
}
