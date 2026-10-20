import PaneFlipCore
import SwiftUI

/// The gap between the zones of one layout: its own, or the one of the Zones tab until it is changed here.
struct LayoutGapRow: View {
    let layout: NamedLayout
    let defaultGap: Double
    let setGap: (Double?) -> Void
    @State private var draft: Double

    init(layout: NamedLayout, defaultGap: Double, setGap: @escaping (Double?) -> Void) {
        self.layout = layout
        self.defaultGap = defaultGap
        self.setGap = setGap
        _draft = State(initialValue: layout.gap ?? defaultGap)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text("Gap between zones").font(.caption).foregroundStyle(.secondary)
                Spacer(minLength: 6)
                Text(verbatim: "\(Int(draft)) px").font(.caption).monospacedDigit().foregroundStyle(.secondary)
                if layout.gap != nil {
                    Button("Reset") { setGap(nil) }
                        .controlSize(.mini)
                }
            }
            // Zones move when the slider is let go, not on every step.
            Slider(value: $draft, in: AppSettings.gapRange, step: AppSettings.gapStep) { editing in
                if !editing { setGap(draft) }
            }
            .controlSize(.small)
            .labelsHidden()
        }
        .onChange(of: layout.gap) { draft = layout.gap ?? defaultGap }
        .onChange(of: defaultGap) { if layout.gap == nil { draft = defaultGap } }
    }
}
