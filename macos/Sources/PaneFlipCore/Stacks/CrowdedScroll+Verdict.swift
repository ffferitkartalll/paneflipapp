extension CrowdedScroll {
    /// What becomes of a scroll event.
    public enum Verdict: Equatable {
        /// It goes to the app as it is.
        case pass
        /// It goes to no one.
        case swallow
        /// It goes to the app as the end of the scroll the app saw begin (no movement in it), so the app is not left waiting for one.
        case end
    }
}
