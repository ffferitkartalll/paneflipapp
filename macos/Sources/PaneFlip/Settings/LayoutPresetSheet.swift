import PaneFlipCore
import SwiftUI

/// The window that opens for Add layout: every shape a new layout can start from, drawn for the screen it is for.
struct LayoutPresetSheet: View {
    let screen: ScreenInfo
    /// Adds a layout of the shape; `edit` opens the editor on it at once.
    let pick: (LayoutPreset, _ edit: Bool) -> Void
    @Environment(\.dismiss) private var dismiss

    private static let width: CGFloat = 150

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Add layout").font(.title2.bold())
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: Self.width), spacing: 14)], spacing: 14) {
                    blankTile
                    ForEach(LayoutPreset.suggested(for: screen.size)) { preset in
                        Button {
                            pick(preset, false)
                            dismiss()
                        } label: {
                            LayoutMiniature(root: preset.root, screenSize: screen.size, width: Self.width)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text(verbatim: "\(preset.root.leafIDs.count)"))
                    }
                }
                .padding(2)
            }
            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
        }
        .padding(20)
        .frame(width: 560, height: 520)
    }

    /// The way to a layout of one zone that is open in the editor at once.
    private var blankTile: some View {
        Button {
            pick(.single, true)
            dismiss()
        } label: {
            // Exactly as large as a layout's miniature: the box has the screen's shape and the content sits in it.
            Color.clear
                .aspectRatio(screen.size.width / screen.size.height, contentMode: .fit)
                .frame(width: Self.width)
                .overlay {
                    VStack(spacing: 6) {
                        Image(systemName: "plus").font(.system(size: 22, weight: .regular))
                        Text("Blank layout").font(.callout)
                    }
                    .foregroundStyle(.secondary)
                }
                .background(.quaternary, in: .rect(cornerRadius: 8))
                .overlay { RoundedRectangle(cornerRadius: 8).strokeBorder(.secondary, style: StrokeStyle(lineWidth: 1, dash: [4])) }
        }
        .buttonStyle(.plain)
    }
}
