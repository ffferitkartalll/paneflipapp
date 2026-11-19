import SwiftUI

/// The mask of the search bar: everything but where the island stands, so that the bar comes down from behind it.
struct IslandCutout: View {
    let cover: CGRect?

    var body: some View {
        Rectangle().overlay(alignment: .topLeading) {
            if let cover {
                UnevenRoundedRectangle(bottomLeadingRadius: IslandRim.radius, bottomTrailingRadius: IslandRim.radius)
                    .frame(width: cover.width, height: cover.height)
                    .offset(x: cover.minX, y: cover.minY)
                    .blendMode(.destinationOut)
            }
        }
        .compositingGroup()
    }
}
