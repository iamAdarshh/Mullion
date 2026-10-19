import CoreGraphics

/// Applies the gap setting (PRD §6.1) to a tiled rect.
public enum Gaps {
    /// Insets `rect` so that screen edges get the full `gap` and edges shared with a neighbouring
    /// tile get `gap / 2`. Two snapped neighbours therefore end up exactly `gap` apart.
    ///
    /// An edge counts as a screen edge when it lies within 0.5 pt of the matching edge of `visibleFrame`.
    public static func apply(_ gap: CGFloat, to rect: CGRect, within visibleFrame: CGRect) -> CGRect {
        guard gap > 0 else { return rect }

        func inset(_ edge: CGFloat, _ screenEdge: CGFloat) -> CGFloat {
            abs(edge - screenEdge) < 0.5 ? gap : gap / 2
        }

        let left = inset(rect.minX, visibleFrame.minX)
        let right = inset(rect.maxX, visibleFrame.maxX)
        let top = inset(rect.minY, visibleFrame.minY)
        let bottom = inset(rect.maxY, visibleFrame.maxY)

        return CGRect(
            x: rect.minX + left,
            y: rect.minY + top,
            width: max(rect.width - left - right, 1),
            height: max(rect.height - top - bottom, 1)
        )
    }
}
