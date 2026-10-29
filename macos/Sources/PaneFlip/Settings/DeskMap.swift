import PaneFlipCore
import SwiftUI

/// The displays drawn where the user says they stand on the desk, each to be dragged to its place.
struct DeskMap: View {
    let displays: [ScreenInfo]
    let arrangement: DeskArrangement
    let onChange: (DeskArrangement) -> Void
    /// The display being dragged and the place it would come to rest at, in desk points.
    @State private var dragging: (id: String, origin: CGPoint)?

    var body: some View {
        let frames = arrangement.frames(of: displays.map { (id: $0.displayID, size: $0.size) })
        // The room to drag in is as wide as the displays side by side and as tall as they stacked: the most they can take. It is centred on the committed
        // places only, so that the picture stays still while a display is dragged.
        let union = frames.values.reduce(CGRect.null) { $0.union($1) }
        let room = CGRect(x: union.midX - displays.map(\.size.width).reduce(0, +) / 2, y: union.midY - displays.map(\.size.height).reduce(0, +) / 2,
                          width: displays.map(\.size.width).reduce(0, +), height: displays.map(\.size.height).reduce(0, +))
        GeometryReader { proxy in
            let scale = min(proxy.size.width / room.width, proxy.size.height / room.height)
            let origin = CGPoint(x: (proxy.size.width - room.width * scale) / 2, y: (proxy.size.height - room.height * scale) / 2)
            ForEach(displays) { display in
                let committed = frames[display.displayID] ?? .zero
                let frame = dragging?.id == display.displayID ? CGRect(origin: dragging?.origin ?? committed.origin, size: committed.size) : committed
                Text(verbatim: display.name)
                    .font(.caption.weight(.medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .padding(4)
                    .frame(width: frame.width * scale, height: frame.height * scale)
                    .background(.quaternary, in: .rect(cornerRadius: 4))
                    .overlay { RoundedRectangle(cornerRadius: 4).stroke(Color.accentColor, lineWidth: dragging?.id == display.displayID ? 2 : 1) }
                    .position(x: origin.x + (frame.midX - room.minX) * scale, y: origin.y + (frame.midY - room.minY) * scale)
                    .gesture(DragGesture(coordinateSpace: .named("desk"))
                        .onChanged { dragging = (display.displayID, snapped(committed, by: $0.translation, scale: scale, among: frames, besides: display.displayID)) }
                        .onEnded { value in
                            dragging = nil
                            var placed = frames.mapValues(\.origin)
                            placed[display.displayID] = snapped(committed, by: value.translation, scale: scale, among: frames, besides: display.displayID)
                            onChange(DeskArrangement(origins: placed))
                        })
            }
        }
        .aspectRatio(room.width / room.height, contentMode: .fit)
        .coordinateSpace(.named("desk"))
    }

    /// Where the display comes to rest when dragged by `translation` (in view points): flush against another display, lined up when near one.
    private func snapped(_ frame: CGRect, by translation: CGSize, scale: CGFloat, among frames: [String: CGRect], besides id: String) -> CGPoint {
        let moved = frame.offsetBy(dx: translation.width / scale, dy: translation.height / scale)
        return DeskSnap.origin(of: moved, among: frames.filter { $0.key != id }.map(\.value), threshold: 14 / scale)
    }
}
