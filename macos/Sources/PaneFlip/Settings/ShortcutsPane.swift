import PaneFlipCore
import SwiftUI

/// Tab: every key or key combination the app reacts to.
struct ShortcutsPane: View {
    @Bindable var settings: AppSettings
    @State private var recorder = KeyRecorder()
    @State private var recording: Shortcut?

    private enum Shortcut { case snap, hidePill }

    var body: some View {
        Form {
            Section("Window snapping") {
                row(.snap, title: "Hold while dragging a window",
                    detail: "Zones light up while the keys are held; release the mouse over a zone to add the window.",
                    value: settings.values.snapTrigger, standard: .leftShift) { settings.values.snapTrigger = $0 }
                Text("Click the field, then press any key or combination. Esc cancels.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .disabled(!settings.values.placementEnabled)

            Section("Pill") {
                row(.hidePill, title: "Double-tap to hide the pill",
                    detail: "Hides the pill under the pointer until the pointer moves away. Works with one modifier key: Shift, Control, Option or Command.",
                    value: settings.values.hidePillKey, standard: .leftShift) { trigger in
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

            Section("Zones beyond the screen") {
                SettingRow(title: "Zones beyond the screen's edges",
                           detail: "Lets a layout have zones beyond the left and right edges of a screen, reached by scrolling: with three fingers on the trackpad, or by moving the pointer to the screen's edge. Switched off, the editor does not show them and their apps move to the default zone of the screen.") {
                    Toggle("Zones beyond the screen's edges", isOn: $settings.values.overflowZonesEnabled).labelsHidden()
                }
            }
            .disabled(!settings.values.placementEnabled)

            Section("Scrolling") {
                SettingRow(title: "Scroll with three fingers",
                           detail: "Swipe sideways with three fingers on the trackpad to scroll the layout and bring the zones beyond the screen's edges into view. Switch off the system's three-finger gestures first (System Settings ▸ Trackpad ▸ More Gestures). Reads the trackpad through a private part of macOS, which an update may break.") {
                    Toggle("Scroll with three fingers", isOn: $settings.values.scrollGestureEnabled).labelsHidden()
                }
                SettingRow(title: "Scroll at the screen's edge",
                           detail: "Rest the pointer at the left or right edge of the screen for a second to bring the zones beyond that edge into view. Needs no trackpad.") {
                    Toggle("Scroll at the screen's edge", isOn: $settings.values.edgeScrollEnabled).labelsHidden()
                }
            }
            .disabled(!settings.values.placementEnabled || !settings.values.overflowZonesEnabled)
        }
        .formStyle(.grouped)
        .onDisappear { stopRecording() }
    }

    private func row(_ shortcut: Shortcut, title: LocalizedStringKey, detail: LocalizedStringKey, value: SnapTrigger,
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
