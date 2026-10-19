import CoreGraphics

/// Moves between displays (PRD §6.5).
public enum DisplayNavigator {
    public enum Direction: Sendable {
        case next, previous
    }

    /// Displays ordered by x, then y: left to right, then top to bottom.
    public static func ordered(_ screens: [ScreenGeometry]) -> [ScreenGeometry] {
        screens.sorted { lhs, rhs in
            lhs.frame.minX != rhs.frame.minX ? lhs.frame.minX < rhs.frame.minX : lhs.frame.minY < rhs.frame.minY
        }
    }

    /// The display after (or before) `current`, wrapping around at the ends.
    /// `nil` when there is only one display or `current` isn't in `screens`.
    public static func screen(
        _ direction: Direction,
        from current: ScreenGeometry,
        in screens: [ScreenGeometry]
    ) -> ScreenGeometry? {
        let ordered = ordered(screens)
        guard ordered.count > 1, let index = ordered.firstIndex(where: { $0.id == current.id }) else { return nil }
        let step = direction == .next ? 1 : -1
        return ordered[(index + step + ordered.count) % ordered.count]
    }

    /// `frame` moved to `destination` keeping its position and size relative to the visible frame,
    /// then clamped inside the destination's visible frame and rounded.
    public static func proportionalFrame(
        _ frame: CGRect,
        from source: ScreenGeometry,
        to destination: ScreenGeometry
    ) -> CGRect {
        let from = source.visibleFrame
        let unit = UnitRect(
            x: (frame.minX - from.minX) / from.width,
            y: (frame.minY - from.minY) / from.height,
            width: frame.width / from.width,
            height: frame.height / from.height
        )
        let visible = destination.visibleFrame
        return unit.rect(in: visible).clamped(to: visible).roundedToEdges()
    }
}
