/// What each segment of the stack pill shows.
public enum PillContent: String, CaseIterable, Identifiable, Codable {
    case icon, name, both

    public var id: Self { self }
}
