/// How a display lies against the one before it (the next one to its left) in the arrangement of the displays.
public enum StairStep: Equatable {
    /// Wholly above it: a step of the staircase.
    case up
    /// Level with it, the two overlapping in height: a zone that runs off the edge of the one lands on the other.
    case level
    /// Wholly below it: the staircase goes down.
    case down
}
