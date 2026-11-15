/// How far the grid of a whole layout is: its pictures are being taken and its windows taken away, it is open (or on its way there), or it is closing.
enum LayoutGridPhase {
    case opening, open, closing
}
