import CoreGraphics

/// Computes where an action puts a window (PRD §6.1). Pure; all rects are in AX space.
public enum ActionCalculator {
    /// Smallest size *Shrink* leaves, as a fraction of the visible frame in each dimension.
    static let minimumShrinkFraction: CGFloat = 0.25

    /// The target rect for `action`, rounded to whole points.
    ///
    /// - Parameters:
    ///   - window: The window's current frame. Used by *Maximize Height*, *Center*, *Grow* and *Shrink*.
    ///   - screen: The screen the window is on (see `ScreenLocator`).
    ///   - halfFraction: For half actions, the size step from repeat-to-cycle (½, ⅔ or ⅓).
    ///     `nil` means ½. Ignored for other actions.
    /// - Returns: `nil` for actions that need more than the screen and window: *Restore* needs the saved
    ///   frame and the display moves need the other screens (see `ActionPlanner`).
    public static func targetRect(
        for action: WindowAction,
        window: CGRect,
        screen: ScreenGeometry,
        settings: ActionSettings,
        halfFraction: CGFloat? = nil
    ) -> CGRect? {
        let visible = screen.visibleFrame
        let rect: CGRect

        if let unit = unitRect(for: action, portrait: screen.isPortrait, halfFraction: halfFraction) {
            rect = Gaps.apply(settings.gap, to: unit.rect(in: visible), within: visible)
        } else {
            switch action {
            case .almostMaximize:
                // Size first, then centre: (1 - fraction) / 2 isn't exact in floating point for 0.9.
                let fraction = settings.almostMaximizeFraction
                let size = CGSize(width: visible.width * fraction, height: visible.height * fraction)
                rect = CGRect(
                    x: visible.midX - size.width / 2,
                    y: visible.midY - size.height / 2,
                    width: size.width,
                    height: size.height
                )
            case .maximizeHeight:
                let column = CGRect(x: window.minX, y: visible.minY, width: window.width, height: visible.height)
                let gapped = column.insetBy(dx: 0, dy: settings.gap)
                rect = gapped.clamped(to: visible)
            case .center:
                let size = CGSize(width: min(window.width, visible.width), height: min(window.height, visible.height))
                rect = CGRect(
                    x: visible.midX - size.width / 2,
                    y: visible.midY - size.height / 2,
                    width: size.width,
                    height: size.height
                )
            case .larger:
                let grown = window.insetBy(dx: -settings.resizeStep, dy: -settings.resizeStep)
                let inside = grown.intersection(visible)
                rect = inside.isNull ? grown.clamped(to: visible) : inside
            case .smaller:
                rect = shrunk(window, by: settings.resizeStep, visible: visible)
            default:
                return nil
            }
        }
        return rect.roundedToEdges()
    }

    /// The fraction of the visible frame a tiled action covers, before gaps.
    /// `nil` for actions that aren't tiled.
    ///
    /// On portrait screens thirds run top to bottom, and sixths form a 2 × 3 grid in reading order.
    public static func unitRect(for action: WindowAction, portrait: Bool, halfFraction: CGFloat? = nil) -> UnitRect? {
        switch action.group {
        case .halves:
            half(action, fraction: halfFraction ?? 0.5)
        case .quarters:
            quarterOrigins[action].map { UnitRect(x: $0.x, y: $0.y, width: 0.5, height: 0.5) }
        case .thirds:
            thirdSpans[action].map { third(start: $0.start, length: $0.length, portrait: portrait) }
        case .sixths:
            sixthIndices[action].map { sixth($0, portrait: portrait) }
        case .other:
            action == .maximize ? .full : nil
        case .displays:
            nil
        }
    }

    /// Where a window ends up when the app refuses the target size, for example because of a minimum
    /// size (AC-2): at the target's origin with the size the app kept, moved back inside the visible frame.
    /// It never leaves the screen.
    public static func reanchored(actual: CGRect, target: CGRect, visibleFrame: CGRect) -> CGRect {
        CGRect(origin: target.origin, size: actual.size).movedInside(visibleFrame).roundedToEdges()
    }

    // MARK: Private

    private static let quarterOrigins: [WindowAction: CGPoint] = [
        .topLeft: CGPoint(x: 0, y: 0),
        .topRight: CGPoint(x: 0.5, y: 0),
        .bottomLeft: CGPoint(x: 0, y: 0.5),
        .bottomRight: CGPoint(x: 0.5, y: 0.5),
    ]

    /// Start and length, in thirds.
    private static let thirdSpans: [WindowAction: (start: Int, length: Int)] = [
        .firstThird: (0, 1),
        .centerThird: (1, 1),
        .lastThird: (2, 1),
        .firstTwoThirds: (0, 2),
        .lastTwoThirds: (1, 2),
    ]

    /// Position in reading order.
    private static let sixthIndices: [WindowAction: Int] = [
        .topLeftSixth: 0,
        .topCenterSixth: 1,
        .topRightSixth: 2,
        .bottomLeftSixth: 3,
        .bottomCenterSixth: 4,
        .bottomRightSixth: 5,
    ]

    private static func half(_ action: WindowAction, fraction: CGFloat) -> UnitRect? {
        switch action {
        case .leftHalf: UnitRect(x: 0, y: 0, width: fraction, height: 1)
        case .rightHalf: UnitRect(x: 1 - fraction, y: 0, width: fraction, height: 1)
        case .topHalf: UnitRect(x: 0, y: 0, width: 1, height: fraction)
        case .bottomHalf: UnitRect(x: 0, y: 1 - fraction, width: 1, height: fraction)
        default: nil
        }
    }

    private static func third(start: Int, length: Int, portrait: Bool) -> UnitRect {
        let offset = CGFloat(start) / 3
        let size = CGFloat(length) / 3
        return portrait
            ? UnitRect(x: 0, y: offset, width: 1, height: size)
            : UnitRect(x: offset, y: 0, width: size, height: 1)
    }

    /// Landscape: 3 columns × 2 rows. Portrait: 2 columns × 3 rows. Both in reading order.
    private static func sixth(_ index: Int, portrait: Bool) -> UnitRect {
        let columns = portrait ? 2 : 3
        let rows = portrait ? 3 : 2
        return UnitRect(
            x: CGFloat(index % columns) / CGFloat(columns),
            y: CGFloat(index / columns) / CGFloat(rows),
            width: 1 / CGFloat(columns),
            height: 1 / CGFloat(rows)
        )
    }

    /// Removes `step` from each side, but never makes a dimension smaller than
    /// `minimumShrinkFraction` of the visible frame.
    private static func shrunk(_ window: CGRect, by step: CGFloat, visible: CGRect) -> CGRect {
        let canShrinkWidth = window.width - 2 * step >= visible.width * minimumShrinkFraction
        let canShrinkHeight = window.height - 2 * step >= visible.height * minimumShrinkFraction
        return window.insetBy(dx: canShrinkWidth ? step : 0, dy: canShrinkHeight ? step : 0)
    }
}
