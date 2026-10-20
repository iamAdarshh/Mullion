import CoreGraphics

/// Decides what happens when the user drags a snapped window away and drops it outside every snap
/// area: it gets its size from before the snap back, under the cursor (PRD §6.3).
public enum DragAwayPlanner {
    /// - Parameters:
    ///   - window: The window as it was dropped: `frame` is where it is now.
    ///   - frameBeforeDrag: Where the window was when the drag started.
    ///   - cursor: Where the user let go, in AX space.
    /// - Returns: `nil` when the window wasn't in its snapped position as the drag started (Mullion
    ///   never snapped it, or the user has moved it since), or it was dropped back where it was.
    public static func plan(
        for window: WindowContext,
        frameBeforeDrag: CGRect,
        cursor: CGPoint,
        screens: [ScreenGeometry]
    ) -> ActionPlan? {
        let tolerance = ActionPlanner.snapTolerance
        guard let snap = window.lastSnap,
              let restoreFrame = window.restoreFrame,
              snap.frame.isApproximatelyEqual(to: frameBeforeDrag, tolerance: tolerance),
              !snap.frame.isApproximatelyEqual(to: window.frame, tolerance: tolerance),
              let screen = ScreenLocator.screen(
                  containing: CGRect(origin: cursor, size: CGSize(width: 1, height: 1)),
                  in: screens
              )
        else { return nil }
        let target = restoredFrame(
            size: restoreFrame.size, droppedAt: window.frame, cursor: cursor, visibleFrame: screen.visibleFrame
        )
        return ActionPlan(target: target, screen: screen, record: nil)
    }

    /// A window of `size` placed so the cursor stays the same fraction of the way across it as it was
    /// across the dropped window, with the top edge where it was dropped, kept inside `visibleFrame`.
    static func restoredFrame(
        size: CGSize,
        droppedAt dropped: CGRect,
        cursor: CGPoint,
        visibleFrame: CGRect
    ) -> CGRect {
        let fraction = dropped.width > 0 ? min(max((cursor.x - dropped.minX) / dropped.width, 0), 1) : 0
        let frame = CGRect(x: cursor.x - fraction * size.width, y: dropped.minY, width: size.width, height: size.height)
        return frame.clamped(to: visibleFrame).roundedToEdges()
    }
}
