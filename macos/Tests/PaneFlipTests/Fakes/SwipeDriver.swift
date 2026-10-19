/// Drives a scroller the way a scroll of known distances would: began, moved, ended.
final class SwipeDriver {
    weak var target: StripScroller?

    func send(_ event: StripScroller.Event) { target?.handle(event) }
}
