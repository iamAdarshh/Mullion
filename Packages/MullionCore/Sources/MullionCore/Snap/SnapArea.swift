/// A hot region along a screen edge or in a corner that snaps a dragged window (PRD §6.4).
public enum SnapArea: Hashable, Sendable {
    case left, right, top
    case topLeft, topRight, bottomLeft, bottomRight
    /// The bottom edge of a portrait screen, where thirds would run across the screen.
    case bottom
    /// The outer thirds of an ultrawide screen's top edge. The middle third is `top`.
    case topLeftSixth, topRightSixth
    /// One of the bottom edge's thirds, numbered 0…2 from the left.
    case bottomThird(Int)
    /// The cursor slid along the bottom edge from third `start` into the neighbouring third `current`.
    case bottomTwoThirds(start: Int, current: Int)

    /// The action a drop in this area applies.
    public var action: WindowAction {
        switch self {
        case .left: .leftHalf
        case .right: .rightHalf
        case .top: .maximize
        case .topLeft: .topLeft
        case .topRight: .topRight
        case .bottomLeft: .bottomLeft
        case .bottomRight: .bottomRight
        case .bottom: .bottomHalf
        case .topLeftSixth: .topLeftSixth
        case .topRightSixth: .topRightSixth
        case let .bottomThird(index): [.firstThird, .centerThird, .lastThird][min(max(index, 0), 2)]
        case let .bottomTwoThirds(start, current): min(start, current) == 0 ? .firstTwoThirds : .lastTwoThirds
        }
    }
}
