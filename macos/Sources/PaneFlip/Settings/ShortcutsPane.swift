import PaneFlipCore
import SwiftUI

/// Tab: every key or key combination the app reacts to.
struct ShortcutsPane: View {
    @Bindable var settings: AppSettings
    @State private var recorder = KeyRecorder()
    @State private var recording: Shortcut?

    private typealias ChordPath = WritableKeyPath<SettingsValues, SnapTrigger>
    private static let chordPaths: [ChordPath] = [\.nextWindowShortcut, \.previousWindowShortcut, \.scrollRightShortcut, \.scrollLeftShortcut,
                                              \.zoneUpShortcut, \.zoneLeftShortcut, \.zoneDownShortcut, \.zoneRightShortcut, \.undoWindowShortcut, \.closeWindowUndoNoticeShortcut, \.enlargeWindowShortcut, \.sendToZoneKeys]

    var body: some View {
        Form {
            Section("Caps Lock") {
                SettingRow(title: "Use Caps Lock as a modifier key",
                           detail: "Caps Lock (⇪) can be one of the keys of a shortcut below. The capital letters are then turned on and off with Command (⌘) and Caps Lock (⇪) together.") {
                    Toggle("Use Caps Lock as a modifier key", isOn: $settings.values.capsLockAsModifier).labelsHidden()
                }
            }

            Section("Zone edges") {
                row(.zoneEdgeEdit, title: "Edit the zone edges",
                    detail: "Press these keys twice quickly to show a handle on each line between the zones. A line moves by its handle. Done or Escape ends it.",
                    value: settings.values.zoneEdgeEditKeys, standard: standard(\.zoneEdgeEditKeys)) { settings.values.zoneEdgeEditKeys = $0 }
            }
            .disabled(!settings.values.placementEnabled)

            Section("Window snapping") {
                row(.snap, title: "Hold while dragging a window",
                    detail: "Zones light up while the keys are held during the drag; release the mouse over a zone to add the window.",
                    value: settings.values.snapTrigger, standard: standard(\.snapTrigger)) { settings.values.snapTrigger = $0 }
            }
            .disabled(!settings.values.placementEnabled)

            Section("Windows in a zone") {
                chordRow(.nextWindow, title: "Next window", path: \.nextWindowShortcut)
                chordRow(.previousWindow, title: "Previous window", path: \.previousWindowShortcut)
                chordRow(.enlargeWindow, title: "Enlarge window", path: \.enlargeWindowShortcut)
                row(.windowScroll, title: "Hold while scrolling",
                    detail: "Hold these keys and scroll over a zone with the mouse wheel to move through its windows. Two fingers do it too when Keys and two fingers is chosen in the Trackpad tab.",
                    value: settings.values.windowScrollKeys, standard: standard(\.windowScrollKeys)) { settings.values.windowScrollKeys = $0 }
            }
            .disabled(!settings.values.placementEnabled)

            Section("Sending a window to a zone") {
                chordRow(.sendToZone, title: "Send window to zone", path: \.sendToZoneKeys,
                         detail: "Press these keys to choose a zone for the focused window in the island: the arrow keys move the choice, Return puts the window there, Backspace takes it out of its zone, Escape cancels.")
            }
            .disabled(!settings.values.placementEnabled)

            Section("Undo") {
                chordRow(.undoWindow, title: "Undo the last window action", path: \.undoWindowShortcut)
                chordRow(.closeWindowUndoNotice, title: "Close the window undo message", path: \.closeWindowUndoNoticeShortcut)
            }
            .disabled(!settings.values.placementEnabled)

            Section("Moving between zones") {
                chordRow(.zoneUp, title: "Zone above", path: \.zoneUpShortcut)
                chordRow(.zoneLeft, title: "Zone on the left", path: \.zoneLeftShortcut)
                chordRow(.zoneDown, title: "Zone below", path: \.zoneDownShortcut)
                chordRow(.zoneRight, title: "Zone on the right", path: \.zoneRightShortcut)
            }
            .disabled(!settings.values.placementEnabled || !settings.values.zoneNavigationEnabled)

            Section("Screens beyond the screen") {
                chordRow(.scrollRight, title: "Scroll to the right", path: \.scrollRightShortcut)
                chordRow(.scrollLeft, title: "Scroll to the left", path: \.scrollLeftShortcut)
                row(.stripScroll, title: "Hold while scrolling",
                    detail: "Hold these keys and scroll over the screen with the mouse wheel to slide to the screens beyond its edges. Two fingers do it too when Keys and two fingers is chosen in the Trackpad tab.",
                    value: settings.values.stripScrollKeys, standard: standard(\.stripScrollKeys)) { settings.values.stripScrollKeys = $0 }
            }
            .disabled(!settings.values.placementEnabled || !settings.values.overflowZonesEnabled)
        }
        .formStyle(.grouped)
        .onDisappear { stopRecording() }
    }

    /// The standard shortcut of a row, which depends on whether Caps Lock is a modifier key.
    private func standard(_ path: ChordPath) -> SnapTrigger {
        StandardShortcuts.values(capsLock: settings.values.capsLockAsModifier)[path] ?? SnapTrigger(keys: [])
    }

    private func chordRow(_ shortcut: Shortcut, title: LocalizedStringKey, path: ChordPath, detail: LocalizedStringKey? = nil) -> some View {
        row(shortcut, title: title, detail: detail, value: settings.values[keyPath: path], standard: standard(path)) { trigger in
            // A key with a modifier key, and not the combination of another shortcut here.
            guard let chord = KeyChord(trigger),
                  !Self.chordPaths.filter({ $0 != path }).contains(where: { KeyChord(settings.values[keyPath: $0]) == chord }) else { return }
            settings.values[keyPath: path] = trigger
        }
    }

    private func row(_ shortcut: Shortcut, title: LocalizedStringKey, detail: LocalizedStringKey?, value: SnapTrigger,
                     standard: SnapTrigger, set: @escaping (SnapTrigger) -> Void) -> some View {
        SettingRow(title: title, detail: detail, explanationLast: true) {
            HStack(spacing: 8) {
                // The width belongs to the label: a frame around the button would leave empty space beside it.
                Button { toggleRecording(shortcut, set: set) } label: {
                    Text(verbatim: recording == shortcut && recorder.isRecording ? recordingTitle : value.displayTitle).frame(minWidth: 110)
                }
                Button("Reset") { set(standard) }.disabled(value == standard)
            }
        }
    }

    private var recordingTitle: String {
        recorder.preview.isEmpty ? String(localized: "Press keys") : recorder.preview
    }

    private func toggleRecording(_ shortcut: Shortcut, set: @escaping (SnapTrigger) -> Void) {
        let wasRecording = recording == shortcut && recorder.isRecording   // Esc stops the recorder and leaves `recording` set
        stopRecording()
        guard !wasRecording else { return }
        recording = shortcut
        recorder.start {
            set($0)
            recording = nil
        }
    }

    private func stopRecording() {
        recorder.stop()
        recording = nil
    }
}
