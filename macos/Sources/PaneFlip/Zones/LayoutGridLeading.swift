import CoreGraphics
import Foundation

/// What the fingers lead of the grid of the whole layout: it opens with a swipe up and closes with one down, following the fingers as the grid of one zone does.
protocol LayoutGridLeading: AnyObject {
    /// The fingers went `up` points (negative: down).
    func moveLead(by up: CGFloat, at time: TimeInterval)
    /// The fingers lifted.
    func endLead()
}
