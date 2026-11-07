/// A button of the open island the pointer can be over: it lights up while it is.
enum IslandButton: Hashable {
    case corner(IslandCornerAction), noticeUndo, noticeClose, noticeRevert
    /// A button of a card (`IslandWindow.id`), and the one that ticks its app.
    case card(IslandCardAction, String), select(String)
}
