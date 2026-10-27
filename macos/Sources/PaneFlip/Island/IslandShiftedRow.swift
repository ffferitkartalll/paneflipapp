import SwiftUI

/// A row of the window carousel. It reads the front card and the finger drag itself, so only this small body runs for each finger event
/// and the cards (built by the parent, which does not read them) are laid out again, not rebuilt.
struct IslandShiftedRow<Content: View>: View {
    let model: MenuBarIslandModel
    let size: CGSize
    @ViewBuilder let content: Content

    var body: some View {
        IslandCardsLayout(wide: size.width, fit: model.cardsFit, height: size.height, at: model.cardsAt ?? 0, other: model.cardsOther, hasFront: model.cardsAt != nil, focus: model.pinnedFront.map { CGFloat($0) }, carried: model.carried, carriedX: model.carriedX, discrete: model.carriedCard != nil || model.windows.contains(where: \.isPlaceholder), frontIndex: model.windows.firstIndex(where: \.isActive)) { content }
    }
}
