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
        let layout = repository.activeLayout(for: screen.key) ?? layouts.addLayout(for: screen.key, preset: .single)
        edit(on: screen, layoutID: layout.id)
    }

    func edit(on screen: ScreenInfo, layoutID: UUID) {
        hide()
        guard let layout = repository.layout(id: layoutID, key: screen.key) else { return }
        let showsOverflow = settings.values.overflowZonesEnabled
        let model = EditorModel(
            strip: showsOverflow ? layout.strip : StripLayout(root: layout.root),
            allowsOverflow: showsOverflow,
            onApply: { [layouts, repository] strip in
                // Switched off, the editor saw only the screen: the areas beyond it stay as they are.
                let result = showsOverflow ? strip : repository.layout(id: layoutID, key: screen.key).map { strip.keepingAreas(of: $0.strip) } ?? strip
                layouts.updateLayout(key: screen.key, id: layoutID, strip: result)
            },
            onClose: { [weak self] in self?.hide() })

        let frame = screen.cocoaVisibleFrame
        let p = EditorPanel(contentRect: frame, styleMask: [.borderless], backing: .buffered, defer: false)
        p.level = .statusBar
        p.backgroundColor = .black
        p.setFrame(frame, display: true)
        p.contentView = NSHostingView(rootView: EditorView(model: model, settings: settings, area: frame.size).tint(AppAccent.color))
        p.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        panel = p

        monitor = NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged, .keyDown, .scrollWheel]) { [weak model] event in
            switch event.type {
            case .flagsChanged: model?.shift = event.modifierFlags.contains(.shift)
            case .keyDown where event.keyCode == 53:   // Esc
                model?.close()
                return nil
            case .scrollWheel:
                // The glide after the fingers lifted means nothing; two fingers move a screen along, a wheel steps.
                guard event.momentumPhase.isEmpty else { return nil }
                if event.hasPreciseScrollingDeltas {
                    model?.scrolled(horizontal: event.scrollingDeltaX, finished: event.phase.contains(.ended) || event.phase.contains(.cancelled))
                } else {
                    model?.wheel(event.scrollingDeltaY)
                }
                return nil
            default: break
            }
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
