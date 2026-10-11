import PaneFlipCore
import SwiftUI

/// Tab: how a window gets into a zone.
struct PlacementPane: View {
    @Bindable var settings: AppSettings
    @State private var recorder = KeyRecorder()

    var body: some View {
        Form {
            Section("Window snapping") {
                SettingRow(title: "Hold while dragging a window",
                           detail: "Zones light up while the keys are held; release the mouse over a zone to add the window.") {
                    HStack(spacing: 8) {
                        // The width belongs to the label: a frame around the button would leave empty space beside it.
                        Button(action: toggleRecording) {
                            Text(verbatim: triggerTitle).frame(minWidth: 110)
                        }
                        Button("Reset") { settings.snapTrigger = .leftShift }
                            .disabled(settings.snapTrigger == .leftShift)
                    }
                }
                Text("Click the field, then press any key or combination. Esc cancels.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .disabled(!settings.placementEnabled)
        }
        .formStyle(.grouped)
        .onDisappear { recorder.stop() }
    }

    private var triggerTitle: String {
        guard recorder.isRecording else { return settings.snapTrigger.displayTitle }
        return recorder.preview.isEmpty ? String(localized: "Press keys") : recorder.preview
    }

    private func toggleRecording() {
        if recorder.isRecording { recorder.stop() }
        else { recorder.start { settings.snapTrigger = $0 } }
    }
}
