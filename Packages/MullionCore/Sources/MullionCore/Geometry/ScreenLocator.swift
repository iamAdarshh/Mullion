import CoreGraphics

/// Finds the screen a window belongs to.
public enum ScreenLocator {
    /// The screen whose frame overlaps the largest area of `windowFrame` (PRD §6.1).
    /// A window that overlaps no screen belongs to the screen nearest to its centre.
    /// Returns `nil` only when `screens` is empty.
    public static func screen(containing windowFrame: CGRect, in screens: [ScreenGeometry]) -> ScreenGeometry? {
        let overlaps = screens.map { ($0, $0.frame.intersection(windowFrame).area) }
        if let best = overlaps.max(by: { $0.1 < $1.1 }), best.1 > 0 {
            return best.0
        }
        let center = CGPoint(x: windowFrame.midX, y: windowFrame.midY)
        return screens.min { $0.frame.distance(to: center) < $1.frame.distance(to: center) }
    }
}
