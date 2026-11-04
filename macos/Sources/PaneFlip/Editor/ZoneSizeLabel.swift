import SwiftUI

/// What a zone says of its size, in the layout editor and on the desktop: its size in points, and, when its line stands on a step (a half, a third and the like),
/// its share under that. The two lines are one block, so the block stays centred where the zone is; the share comes and goes with a fade, and the size does
/// not fade, it only moves up.
struct ZoneSizeLabel: View {
    let size: String
    let share: (numerator: Int, denominator: Int)?

    var body: some View {
        VStack(spacing: 2) {
            Text(verbatim: size).contentTransition(.identity).foregroundStyle(.white.opacity(share == nil ? 0.4 : 0.9))
            if let share {
                Text(verbatim: "\(share.numerator)/\(share.denominator)").foregroundStyle(.white.opacity(0.9)).transition(.opacity)
            }
        }
        .font(.title3.monospacedDigit())
        .animation(.smooth(duration: 0.2), value: share != nil)
    }
}
