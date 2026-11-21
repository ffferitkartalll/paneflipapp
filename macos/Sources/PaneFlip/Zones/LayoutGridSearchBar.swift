import SwiftUI

/// The search bar over the grid of a whole layout, between the menu bar and the zones: the text typed, or what it is for, and at its right end how many zones and windows the grid
/// has. Made as the cards are: on their ground, with the light line round it and their shadow, the buttons in the accent colour. The keys typed go to it from the grid (`LayoutGridOverlay`);
/// a click on its text part gives it the keys (a click on the rest does nothing but keep the grid open), and its icon at the left, while it is searching, is the button that ends the search.
struct LayoutGridSearchBar: View {
    @Bindable var search: LayoutGridSearch
    static let width: CGFloat = 440
    @State private var overButton = false
    @State private var selection: TextSelection?
    /// What the icon shows: it follows `searching` inside an animation of its own, so that the turn happens whatever it was that began the search (a key, a click).
    @State private var showsClose = false
    @FocusState private var focused: Bool
    /// Searching: something is typed, or the bar was clicked (it has the keys and shows a caret). The search icon is then the button that ends it.
    private var searching: Bool { focused || !search.query.isEmpty }

    var body: some View {
        HStack(spacing: 8) {
            // The search icon, or, while searching, the button that ends the search: the one turns away as the other turns in, and the button lights under the pointer.
            ZStack {
                if showsClose {
                    Image(systemName: "xmark").fontWeight(.semibold).foregroundStyle(AppAccent.color)
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(AppAccent.color.opacity(overButton ? 0.22 : 0)))
                        .scaleEffect(overButton ? 1.12 : 1)
                        .animation(.easeOut(duration: 0.15), value: overButton)
                        .contentShape(Circle())
                        .onHover { overButton = $0 }
                        .onTapGesture { search.onClear() }
                        .transition(.asymmetric(insertion: .spin(-90, comesIn: true), removal: .spin(90, comesIn: false)))
                } else {
                    Image(systemName: "magnifyingglass").fontWeight(.semibold).foregroundStyle(AppAccent.color)
                        .frame(width: 22, height: 22)
                        .transition(.asymmetric(insertion: .spin(90, comesIn: true), removal: .spin(-90, comesIn: false)))
                }
            }
            .frame(width: 22, height: 22)
            .pointerStyle(.default)
            // A text field as any other: the caret, the selection, paste and the input methods are its own. It has no caret until a key or a click gives it the keys. A click
            // activates the search only here, where the text is typed (the bar's other parts take the click and do nothing): in the field itself, and in the room round it.
            ZStack {
                Color.clear.contentShape(Rectangle()).onTapGesture { focused = true }
                TextField(text: $search.query, selection: $selection, prompt: Text("Search windows").foregroundStyle(Color.contrast.opacity(0.55))) { EmptyView() }
                    .textFieldStyle(.plain)
                    .foregroundStyle(Color.contrast)
                    .tint(AppAccent.color)
                    .focused($focused)
                    .lineLimit(1)
            }
            .frame(height: LayoutGridModel.searchBarHeight)
            .pointerStyle(.horizontalText)   // the text cursor is for where text is typed; everywhere else in the bar and the grid the pointer is the arrow
            HStack(spacing: 0) { Text("\(search.zones) zones"); Text(verbatim: " · "); Text("\(search.windows) windows") }.foregroundStyle(Color.contrast.opacity(0.55)).monospacedDigit().lineLimit(1)
        }
        .font(.system(size: 14))
        .padding(.horizontal, 12)
        .frame(width: Self.width, height: LayoutGridModel.searchBarHeight)
        .background { RoundedRectangle(cornerRadius: 10).fill(CardEdge.ground.opacity(0.85)).shadow(color: CardEdge.shadow, radius: 16, y: 5) }
        .overlay { RoundedRectangle(cornerRadius: 10).strokeBorder(CardEdge.inner, lineWidth: 1) }
        .contentShape(RoundedRectangle(cornerRadius: 10))
        .pointerStyle(.default)
        .onTapGesture {}   // a click on the bar is not one on the grid behind it
        .onChange(of: searching) { withAnimation { showsClose = searching } }
        .onChange(of: focused) { if focused { selection = TextSelection(insertionPoint: search.query.endIndex) } }   // typing goes on at the end, it does not replace the text
        .onChange(of: search.focusToken) { focused = true }
        .onChange(of: search.blurToken) { focused = false }
        .onChange(of: search.query) { search.onChange() }
    }
}
