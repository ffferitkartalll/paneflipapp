import SwiftUI

/// A setting adjusted with a slider. Stacked rather than side by side: the title and the current value share the
/// top line, the slider spans the full width below it, and the explanation sits underneath. With the text beside
/// the slider, wrapped text always left a gap before it.
struct SliderSettingRow: View {
    let title: LocalizedStringKey
    let detail: LocalizedStringKey
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    var unit = "px"
    var onEditingChanged: (Bool) -> Void = { _ in }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                Spacer(minLength: 12)
                Text(verbatim: "\(Int(value)) \(unit)")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            Slider(value: $value, in: range, step: step, onEditingChanged: onEditingChanged)
                .labelsHidden()
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)   // wrap, never truncate
        }
        .padding(.vertical, 4)
    }
}
