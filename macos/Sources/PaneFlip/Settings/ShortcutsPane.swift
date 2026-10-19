import PaneFlipCore
import SwiftUI

/// Tab: every key or key combination the app reacts to.
struct ShortcutsPane: View {
    @Bindable var settings: AppSettings
    @State private var recorder = KeyRecorder()
    @State private var recording: Shortcut?

    private enum Shortcut { case snap, hidePill, nextWindow, previousWindow, scrollRight, scrollLeft }

    private typealias ChordPath = WritableKeyPath<SettingsValues, SnapTrigger>
    private static let chordPaths: [ChordPath] = [\.nextWindowShortcut, \.previousWindowShortcut, \.scrollRightShortcut, \.scrollLeftShortcut]

    var body: some View {
        Form {
            Section("Window snapping") {
                row(.snap, title: "Hold while dragging a window",
                    detail: "Zones light up while the keys are held; release the mouse over a zone to add the window.",
                    value: settings.values.snapTrigger, standard: .leftCommand) { settings.values.snapTrigger = $0 }
                Text("Click the field, then press any key or combination. Esc cancels.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .disabled(!settings.values.placementEnabled)

            Section("Pill") {
                row(.hidePill, title: "Double-tap to hide the pill",
                    detail: "Hides the pill under the pointer until the pointer moves away. Works with one modifier key: Shift, Control, Option or Command.",
                    value: settings.values.hidePillKey, standard: .leftCommand) { trigger in
                    // A double tap is only seen for a single modifier key.
                    if trigger.keys.count == 1, let code = trigger.keys.first?.code, SnapTrigger.modifierMasks[code] != nil {
                        settings.values.hidePillKey = trigger
                    }
                }
                Text("Click the field, then press a modifier key. Esc cancels.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .disabled(!settings.values.placementEnabled || !settings.values.stackingEnabled)

            Section("Windows in a zone") {
                chordRow(.nextWindow, title: "Next window", path: \.nextWindowShortcut, standard: .nextWindow)
                chordRow(.previousWindow, title: "Previous window", path: \.previousWindowShortcut, standard: .previousWindow)
                chordHint
            }
            .disabled(!settings.values.placementEnabled || !settings.values.stackingEnabled)

            Section("Zones beyond the screen") {
                chordRow(.scrollRight, title: "Scroll to the right", path: \.scrollRightShortcut, standard: .scrollRight)
                chordRow(.scrollLeft, title: "Scroll to the left", path: \.scrollLeftShortcut, standard: .scrollLeft)
                chordHint
            }
            .disabled(!settings.values.placementEnabled || !settings.values.overflowZonesEnabled)
        }
        .formStyle(.grouped)
        .onDisappear { stopRecording() }
    }

    private var chordHint: some View {
        Text("Click the field, then press a key with at least one modifier key. Esc cancels.")
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    private func chordRow(_ shortcut: Shortcut, title: LocalizedStringKey, path: ChordPath, standard: SnapTrigger) -> some View {
        row(shortcut, title: title, detail: nil, value: settings.values[keyPath: path], standard: standard) { trigger in
            // A key with a modifier key, and not the combination of another shortcut here.
            guard let chord = KeyChord(trigger),
                  !Self.chordPaths.filter({ $0 != path }).contains(where: { KeyChord(settings.values[keyPath: $0]) == chord }) else { return }
            settings.values[keyPath: path] = trigger
        }
    }

    private func row(_ shortcut: Shortcut, title: LocalizedStringKey, detail: LocalizedStringKey?, value: SnapTrigger,
                     standard: SnapTrigger, set: @escaping (SnapTrigger) -> Void) -> some View {
        SettingRow(title: title, detail: detail) {
            HStack(spacing: 8) {
                // The width belongs to the label: a frame around the button would leave empty space beside it.
                Button { toggleRecording(shortcut, set: set) } label: {
                    Text(verbatim: recording == shortcut ? recordingTitle : value.displayTitle).frame(minWidth: 110)
                }
                Button("Reset") { set(standard) }.disabled(value == standard)
            }
        }
    }

    private var recordingTitle: String {
        recorder.preview.isEmpty ? String(localized: "Press keys") : recorder.preview
    }

    private func toggleRecording(_ shortcut: Shortcut, set: @escaping (SnapTrigger) -> Void) {
        let wasRecording = recording == shortcut
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
