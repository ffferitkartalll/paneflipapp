import SwiftUI

/// One setting: its title and explanation on the left, its control on the right. Every row in every tab is built
/// from this, so titles, descriptions and controls line up the same way everywhere.
struct SettingRow<Control: View>: View {
    let title: LocalizedStringKey
    var detail: LocalizedStringKey?
    @ViewBuilder let control: Control

    var body: some View {
        HStack(alignment: .center, spacing: 20) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                if let detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)   // wrap, never truncate
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            control.fixedSize()   // natural size, hugging the trailing edge; never overlaps the text column
        }
        .padding(.vertical, 4)
    }
}
