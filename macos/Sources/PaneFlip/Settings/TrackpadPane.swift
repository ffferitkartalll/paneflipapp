import PaneFlipCore
import SwiftUI

/// Tab: what the trackpad moves through the windows and the zones beyond the screen with, and how fast.
struct TrackpadPane: View {
    @Bindable var settings: AppSettings

    var body: some View {
        Form {
            Section("Trackpad") {
                SliderSettingRow(title: "Trackpad speed",
                                 detail: "How far the content goes for the same stroke of the fingers. It also follows the tracking speed set for the system's trackpad.",
                                 value: $settings.values.trackpadSpeed, range: AppSettings.trackpadSpeedRange,
                                 step: AppSettings.trackpadSpeedStep, unit: "×")
                SettingRow(title: "Move with",
                           detail: settings.values.trackpadMethod == .keysAndTwoFingers
                               ? "Hold the scroll keys (set in the Shortcuts tab) and scroll with two fingers."
                               : "Swipe sideways with three fingers to move through a zone's windows, and with four fingers to slide to the zones beyond the screen. No keys are needed.",
                           controlBelow: true) {
                    VStack(alignment: .leading, spacing: 10) {
                        FullWidthSegments(selection: $settings.values.trackpadMethod,
                                          options: TrackpadMethod.allCases.map { ($0, $0.title) })
                            .accessibilityLabel("Move with")
                        if settings.values.trackpadMethod == .threeAndFourFingers { systemGesturesWarning }
                    }
                }
            }
            .disabled(!settings.values.placementEnabled)
        }
        .formStyle(.grouped)
    }

    private var systemGesturesWarning: some View {
        Label {
            Text("Turn off the system's own swipes with three and four fingers first (System Settings ▸ Trackpad ▸ More Gestures), or macOS acts on them too.")
                .font(.callout.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.orange.opacity(0.15), in: .rect(cornerRadius: 10))
    }
}
