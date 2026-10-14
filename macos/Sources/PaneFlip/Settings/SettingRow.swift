import SwiftUI

/// One setting: its title and explanation on the left, its control on the right. Every row in every tab is built
/// from this, so titles, descriptions and controls line up the same way everywhere. A control that needs room (a
/// segmented picker next to a long explanation) goes below the texts instead, at the full width.
struct SettingRow<Control: View>: View {
    let title: LocalizedStringKey
    var detail: LocalizedStringKey?
    var controlBelow = false
    @ViewBuilder let control: Control

    var body: some View {
        if controlBelow {
            VStack(alignment: .leading, spacing: 8) {
                texts
                control
            }
            .padding(.vertical, 4)
        } else {
            HStack(alignment: .center, spacing: 20) {
                texts
                control.fixedSize()   // natural size, hugging the trailing edge; never overlaps the text column
            }
            .padding(.vertical, 4)
        }
    }

    private var texts: some View {
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
    }
}
