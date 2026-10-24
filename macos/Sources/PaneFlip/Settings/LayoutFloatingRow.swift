import PaneFlipCore
import SwiftUI

/// The floating zone of one layout: whether there is one, which zone of the screen it floats over and how much of it it takes.
struct LayoutFloatingRow: View {
    let layout: NamedLayout
    /// Floats over a zone (nil: no floating zone) with a share of its width and height.
    let setFloatingZone: (_ host: UUID?, _ scale: Double) -> Void
    @State private var draft: Double

    init(layout: NamedLayout, setFloatingZone: @escaping (UUID?, Double) -> Void) {
        self.layout = layout
        self.setFloatingZone = setFloatingZone
        _draft = State(initialValue: layout.floatingZone?.scale ?? FloatingZone.defaultScale)
    }

    private var floating: FloatingZone? { layout.floatingZone }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle("Floating zone", isOn: Binding(
                get: { floating != nil },
                set: { setFloatingZone($0 ? layout.fallbackZoneID : nil, draft) }))
                .font(.caption)
                .toggleStyle(.switch)
                .controlSize(.small)
            if let floating {
                Picker("Floats over", selection: Binding(get: { floating.host }, set: { setFloatingZone($0, draft) })) {
                    ForEach(layout.root.leafIDs, id: \.self) { zone in
                        Text(verbatim: ZoneLabel.text(of: zone, in: layout.strip)).tag(zone)
                    }
                }
                .font(.caption)
                .controlSize(.small)
                HStack {
                    Text("Size").font(.caption).foregroundStyle(.secondary)
                    Spacer(minLength: 6)
                    Text(verbatim: "\(Int((draft * 100).rounded())) %").font(.caption).monospacedDigit().foregroundStyle(.secondary)
                }
                // The zone changes when the slider is let go, not on every step.
                Slider(value: $draft, in: FloatingZone.scaleRange, step: 0.05) { editing in
                    if !editing { setFloatingZone(floating.host, draft) }
                }
                .controlSize(.small)
                .labelsHidden()
            }
        }
        .onChange(of: floating?.scale) { if let scale = floating?.scale { draft = scale } }
    }
}
