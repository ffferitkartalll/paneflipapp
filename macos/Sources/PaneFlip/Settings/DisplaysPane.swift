import AppKit
import PaneFlipCore
import SwiftUI

/// Tab: how macOS arranges the displays (a staircase going up to the right keeps the zones beyond a display's edge off the others) and where the
/// displays really stand on the desk, which the moves from one display to the next follow.
struct DisplaysPane: View {
    let screens: ScreenProviding
    @Bindable var settings: AppSettings
    /// Bumped when displays are plugged in or out or arranged again, so the list of screens is read again.
    @State private var displaysChanged = 0

    var body: some View {
        let _ = displaysChanged
        let displays = DeskSpace.distinct(screens.screens())
        let stairs = DisplayStairs(displays.map { ($0.displayID, $0.cocoaFrame) })
        let desk = settings.values.deskArrangement
        Form {
            Section("Arrangement in macOS") {
                DisplayMap(displays: displays, stairs: stairs)
                    .frame(height: 200)
                    .padding(.vertical, 6)
                status(of: stairs, count: displays.count)
                Button("Open Displays settings") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.Displays-Settings.extension") { NSWorkspace.shared.open(url) }
                }
            }

            if displays.count > 1 {
                Section("Arrangement on your desk") {
                    Text("Drag the displays to where they stand on your desk. PaneFlip uses this arrangement for the moves from one display to the next.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    DeskMap(displays: displays, arrangement: desk) { settings.values.deskArrangement = $0 }
                        .frame(maxHeight: 360)
                        .padding(.vertical, 6)
                    if !desk.isSet(for: displays.map { (id: $0.displayID, size: $0.deskSize) }) {
                        Text("Not set yet. Until you move a display, PaneFlip uses the arrangement in macOS.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)) { _ in
            displaysChanged += 1
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            displaysChanged += 1
        }
    }

    @ViewBuilder
    private func status(of stairs: DisplayStairs, count: Int) -> some View {
        if count < 2 {
            Label("There is only one display, so there is nothing to arrange.", systemImage: "display")
                .foregroundStyle(.secondary)
        } else if stairs.isStaircase {
            Label("The displays form a staircase going up to the right.", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        } else {
            VStack(alignment: .leading, spacing: 4) {
                Label("The displays do not form a staircase yet.", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                if stairs.steps.contains(.level) {
                    Text("Some displays are level with the one to their left, so a screen beyond the edge of one lands on the other.")
                }
                if stairs.steps.contains(.down) {
                    Text("Some displays lie lower than the one to their left. The staircase must go up to the right.")
                }
            }
            .font(.callout)
            .fixedSize(horizontal: false, vertical: true)
        }
    }
}
