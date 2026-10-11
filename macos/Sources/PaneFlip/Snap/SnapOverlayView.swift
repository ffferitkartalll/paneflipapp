import SwiftUI

struct SnapOverlayView: View {
    let model: SnapOverlayModel
    let screenFrame: CGRect

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(model.zones) { zone in
                let r = zone.cocoaRect
                if r.intersects(screenFrame) {
                    let hot = zone.id == model.hoverID
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.accentColor.opacity(hot ? 0.4 : 0.15))
                        .strokeBorder(Color.accentColor.opacity(hot ? 1 : 0.6), lineWidth: hot ? 3 : 2)
                        .frame(width: r.width, height: r.height)
                        .offset(x: r.minX - screenFrame.minX, y: screenFrame.maxY - r.maxY)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .animation(.easeOut(duration: 0.12), value: model.hoverID)
    }
}
