/// How the trackpad moves through a zone's windows and on to the zones beyond the screen.
public enum TrackpadMethod: String, CaseIterable, Identifiable, Codable {
    /// Two fingers while the scroll keys are held.
    case keysAndTwoFingers
    /// Three fingers for the windows of a zone, four for the zones beyond the screen, no keys.
    case threeAndFourFingers

    public var id: Self { self }
}
