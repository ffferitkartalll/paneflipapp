import PaneFlipCore
import SwiftUI

/// The apps of one layout: for each zone, the apps that are in it and the order the island shows them in. An app is moved to another zone, taken out or put in another
/// place of its row here.
struct LayoutAppsView: View {
    let layout: NamedLayout
    /// The name the layout is shown under (a layout without a name of its own has a default one).
    let title: String
    let editor: LayoutAppsEditing
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modalRoom) private var room

    /// Every zone, in the order across the strip: beyond the left edge, the screen, beyond the right edge.
    private var zones: [UUID] { layout.strip.zoneIDs }
    private func name(_ zone: UUID) -> String { ZoneLabel.text(of: zone, in: layout.strip) }
    /// "Zone 1", with the name the user gave it after a dot.
    private func zoneTitle(_ zone: UUID) -> Text {
        let number = String(localized: "Zone \(name(zone))")
        return Text(verbatim: layout.zoneNames[zone].map { "\(number) · \($0)" } ?? number)
    }

    var body: some View {
        let entries = editor.entries(inZones: zones)
        VStack(alignment: .leading, spacing: 12) {
            Text(verbatim: title).font(.title3.bold())
            Text("The apps placed in the zones of this layout, in the order the island shows them. Drag an app by its handle to change the order, or move it to another zone.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Form {
                ForEach(zones, id: \.self) { zone in
                    Section {
                        ZoneAppsList(entries: entries.filter { $0.zoneID == zone }, zones: zones, title: zoneTitle, editor: editor)
                    } header: {
                        zoneTitle(zone)
                    }
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)   // the form's own background is a shade off the sheet's
            // The grouped form insets its cards by about 20 pt on each side: the sheet's own padding is enough, so the cards line
            // up with the text above them.
            .padding(.horizontal, -20)
            HStack {
                Spacer()
                Button("Reset") { editor.clear(zones: zones) }
                Button("Done") { dismiss() }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: room.width, height: room.height)   // all the room there is: the room inside the sheet it opens over
    }
}
