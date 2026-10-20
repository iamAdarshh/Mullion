/// A hot region along a screen edge or in a corner that snaps a dragged window (PRD §6.4).
public enum SnapArea: Hashable, Sendable {
    case left, right, top
    case topLeft, topRight, bottomLeft, bottomRight
    /// The bottom edge of a portrait screen, where thirds would run across the screen.
    case bottom
    /// The outer thirds of an ultrawide screen's top edge. The middle third is `top`.
    case topLeftSixth, topRightSixth
    /// One of the bottom edge's thirds.
    case bottomThird(BottomThird)
    /// The cursor slid along the bottom edge from one third into its neighbour.
    case bottomTwoThirds(BottomSlide)

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
        case let .bottomThird(third): third.action
        case let .bottomTwoThirds(slide): slide.action
        }
    }
}

/// A third of a screen's width, from the left.
public enum BottomThird: Int, CaseIterable, Sendable {
    case first, center, last

    var action: WindowAction {
        switch self {
        case .first: .firstThird
        case .center: .centerThird
        case .last: .lastThird
        }
    }
}

/// A slide along the bottom edge between neighbouring thirds. Only neighbours can be slid between,
/// so every case covers exactly two adjacent thirds.
public enum BottomSlide: Sendable {
    case firstToCenter, centerToFirst, centerToLast, lastToCenter

    /// The slide from `start` into `current`, or `nil` unless they are neighbours.
    public init?(from start: BottomThird, to current: BottomThird) {
        switch (start, current) {
        case (.first, .center): self = .firstToCenter
        case (.center, .first): self = .centerToFirst
        case (.center, .last): self = .centerToLast
        case (.last, .center): self = .lastToCenter
        default: return nil
        }
    }

    /// The third the slide started in.
    public var start: BottomThird {
        switch self {
        case .firstToCenter: .first
        case .centerToFirst, .centerToLast: .center
        case .lastToCenter: .last
        }
    }

    /// The third the cursor is in now.
    public var current: BottomThird {
        switch self {
        case .centerToFirst: .first
        case .firstToCenter, .lastToCenter: .center
        case .centerToLast: .last
        }
    }

    var action: WindowAction {
        switch self {
        case .firstToCenter, .centerToFirst: .firstTwoThirds
        case .centerToLast, .lastToCenter: .lastTwoThirds
        }
    }
}
