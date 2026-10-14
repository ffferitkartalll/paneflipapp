/// What each segment of the stack pill shows.
public enum PillContent: String, CaseIterable, Identifiable, Codable {
    /// In the order the settings offer them.
    case icon, both, name

    public var id: Self { self }
}
