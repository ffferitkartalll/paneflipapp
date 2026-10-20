/// Which edge of its zone the stack pill sits along.
public enum PillPosition: String, CaseIterable, Identifiable, Codable {
    case top, bottom

    public var id: Self { self }
}
