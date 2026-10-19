import CoreGraphics

/// Decides what an action does to a window, given everything Mullion knows about it.
/// Covers plain actions (PRD §6.1), repeat-to-cycle (§6.2), restore (§6.3) and display moves (§6.5).
public enum ActionPlanner {
    /// How far a window may drift from its recorded frame and still count as snapped.
    /// Matches the 2 pt tolerance for apps that round sizes (ARCHITECTURE §11).
    static let snapTolerance: CGFloat = 2

    /// - Returns: `nil` when the action does nothing: no screens, *Restore* with nothing saved,
    ///   a display move with one display, or a repeated half set to *Do nothing*.
    public static func plan(
        _ action: WindowAction,
        for window: WindowContext,
        screens: [ScreenGeometry],
        settings: ActionSettings
    ) -> ActionPlan? {
        guard let screen = ScreenLocator.screen(containing: window.frame, in: screens) else { return nil }
        // A record only counts while the window is still where Mullion put it.
        let snapped = window.lastSnap.flatMap {
            $0.frame.isApproximatelyEqual(to: window.frame, tolerance: snapTolerance) ? $0 : nil
        }
        let request = Request(
            window: window.frame,
            screen: screen,
            screens: screens,
            snapped: snapped,
            settings: settings
        )

        switch action {
        case .restore:
            return window.restoreFrame.map { restore($0, screens: screens, fallback: screen) }
        case .nextDisplay:
            return request.moveToDisplay(.next)
        case .previousDisplay:
            return request.moveToDisplay(.previous)
        default:
            if action.isHalf, let snapped, snapped.action == action {
                return request.repeated(snapped)
            }
            return request.apply(action, halfFraction: nil, on: screen)
        }
    }

    // MARK: Private

    private static func restore(_ frame: CGRect, screens: [ScreenGeometry], fallback: ScreenGeometry) -> ActionPlan {
        let screen = ScreenLocator.screen(containing: frame, in: screens) ?? fallback
        // Put the frame back exactly, even across two displays or partly off screen. Only when its
        // display has been disconnected (it overlaps no screen) is it moved onto a connected one.
        let isOnAScreen = screens.contains { $0.frame.intersects(frame) }
        let target = isOnAScreen ? frame : frame.clamped(to: screen.visibleFrame)
        return ActionPlan(target: target, screen: screen, record: nil)
    }

    /// The inputs shared by every planning step.
    private struct Request {
        let window: CGRect
        let screen: ScreenGeometry
        let screens: [ScreenGeometry]
        let snapped: SnapRecord?
        let settings: ActionSettings

        func apply(_ action: WindowAction, halfFraction: CGFloat?, on screen: ScreenGeometry) -> ActionPlan? {
            ActionCalculator.targetRect(
                for: action, window: window, screen: screen, settings: settings, halfFraction: halfFraction
            ).map { target in
                let record = action
                    .isTiled ? SnapRecord(action: action, halfFraction: halfFraction, frame: target) : nil
                return ActionPlan(target: target, screen: screen, record: record)
            }
        }

        func repeated(_ snapped: SnapRecord) -> ActionPlan? {
            switch settings.repeatBehavior {
            case .cycleSizes:
                let next = CycleState.next(after: snapped.halfFraction)
                // ½ is stored as nil so a full cycle ends exactly where a fresh half starts.
                let fraction = next == CycleState.fractions[0] ? nil : next
                return apply(snapped.action, halfFraction: fraction, on: screen)
            case .doNothing:
                return nil
            case .moveToNextDisplay:
                let destination = DisplayNavigator.screen(.next, from: screen, in: screens) ?? screen
                return apply(snapped.action, halfFraction: snapped.halfFraction, on: destination)
            }
        }

        func moveToDisplay(_ direction: DisplayNavigator.Direction) -> ActionPlan? {
            guard let destination = DisplayNavigator.screen(direction, from: screen, in: screens) else { return nil }
            if let snapped {
                return apply(snapped.action, halfFraction: snapped.halfFraction, on: destination)
            }
            let target = DisplayNavigator.proportionalFrame(window, from: screen, to: destination)
            return ActionPlan(target: target, screen: destination, record: nil)
        }
    }
}
