/// A named window operation (PRD §6.1). Every shortcut, menu item and drag target maps to one action.
///
/// Raw values are persisted (configs, shortcut storage). Never rename one without a migration.
public enum WindowAction: String, CaseIterable, Codable, Sendable {
    case leftHalf, rightHalf, topHalf, bottomHalf
    case topLeft, topRight, bottomLeft, bottomRight
    case firstThird, centerThird, lastThird, firstTwoThirds, lastTwoThirds
    case topLeftSixth, topCenterSixth, topRightSixth
    case bottomLeftSixth, bottomCenterSixth, bottomRightSixth
    case maximize, almostMaximize, maximizeHeight, center, larger, smaller, restore
    case nextDisplay, previousDisplay

    /// Menu sections, in menu order (PRD §6.7).
    public enum Group: CaseIterable, Sendable {
        case halves, quarters, thirds, sixths, other, displays
    }

    public var group: Group {
        switch self {
        case .leftHalf, .rightHalf, .topHalf, .bottomHalf:
            .halves
        case .topLeft, .topRight, .bottomLeft, .bottomRight:
            .quarters
        case .firstThird, .centerThird, .lastThird, .firstTwoThirds, .lastTwoThirds:
            .thirds
        case .topLeftSixth, .topCenterSixth, .topRightSixth, .bottomLeftSixth, .bottomCenterSixth, .bottomRightSixth:
            .sixths
        case .maximize, .almostMaximize, .maximizeHeight, .center, .larger, .smaller, .restore:
            .other
        case .nextDisplay, .previousDisplay:
            .displays
        }
    }

    /// Half actions take part in repeat-to-cycle (PRD §6.2).
    public var isHalf: Bool {
        group == .halves
    }

    /// Actions that tile a fixed fraction of the screen. Only these get gaps, and only these
    /// keep their action when the window moves to another display (PRD §6.5).
    public var isTiled: Bool {
        switch group {
        case .halves, .quarters, .thirds, .sixths: true
        case .other: self == .maximize
        case .displays: false
        }
    }
}
