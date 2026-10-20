import CoreGraphics
import Foundation

/// Tells a window drag apart from every other mouse drag (ARCHITECTURE §6).
///
/// Window positions come from the window server (`WindowListing`), never from Accessibility: while
/// the user drags a window by its title bar, its app is busy in the drag loop and every AX read times
/// out. A press costs nothing. Once the mouse has moved `startDistance`, the window under the cursor
/// is looked up once (under the cursor, not the press point: the window has already followed the
/// cursor, so a press near its edge may no longer be over it), and its bounds are compared on later
/// events. The cursor used with a window read is the one sampled with it, not the event's: the window
/// server moves the window before Mullion handles the event, so the event's position lags behind.
/// When the origin moves and the size doesn't, the user is dragging the window. A window
/// that hasn't moved by the time the cursor has travelled `giveUpDistance` means text selection, a
/// scrollbar or a resize, and the rest of that drag is ignored without further reads (test-matrix
/// case 15).
///
/// All points are in AX space.
@MainActor
final class DragTracker {
    /// How far the mouse moves before the window under it is looked up. Filters out plain clicks.
    static let startDistance: CGFloat = 4
    /// How far the cursor may move without the window moving before the drag is ignored.
    static let giveUpDistance: CGFloat = 30
    /// How often a window drag checks that the button is still held.
    static let buttonCheckInterval: TimeInterval = 0.25

    /// The user started dragging a window. Passes the cursor.
    var onMoveStarted: ((DraggedWindow, CGPoint) -> Void)?
    /// The cursor moved while dragging a window.
    var onMoved: ((DraggedWindow, CGPoint) -> Void)?
    /// The user let go of a window they were dragging.
    var onEnded: ((DraggedWindow, CGPoint) -> Void)?
    /// A window drag stopped without a drop, for example because Accessibility was revoked.
    var onCancelled: ((DraggedWindow) -> Void)?

    private enum Phase {
        case idle
        case pressed(CGPoint)
        /// `window.bounds` was read when the cursor was at `readAt` (sampled with the read), after a
        /// press at `press`.
        case checking(ListedWindow, press: CGPoint, readAt: CGPoint)
        case moving(DraggedWindow)
        case ignored
    }

    private let windowList: any WindowListing
    private let ownPID: pid_t
    private let scheduler: any RepeatingScheduler
    private let isLeftButtonDown: () -> Bool
    private var phase = Phase.idle
    /// Runs only while a window is being dragged. A missed release (in Mission Control, say) would
    /// otherwise leave the drag and its preview running until the next click, even if the user only
    /// types in the meantime. Holding the window still sends no events, so a timeout can't tell.
    private var buttonCheck: (any ScheduledTask)?
    /// Checks in a row that found the button up. The button state changes the moment the user lets go,
    /// but the release event reaches Mullion later: cancelling on the first such check could beat it
    /// and lose the drop. By the second check, a release that really happened has arrived.
    private var buttonUpChecks = 0
    private static let buttonUpChecksToCancel = 2

    /// - Parameters:
    ///   - ownPID: Mullion's pid. Its own windows are never snapped.
    ///   - isLeftButtonDown: Whether the left mouse button is held right now.
    init(
        windowList: any WindowListing,
        ownPID: pid_t,
        scheduler: any RepeatingScheduler,
        isLeftButtonDown: @escaping () -> Bool
    ) {
        self.windowList = windowList
        self.ownPID = ownPID
        self.scheduler = scheduler
        self.isLeftButtonDown = isLeftButtonDown
    }

    /// True while a window is being dragged.
    var isDraggingWindow: Bool {
        if case .moving = phase {
            return true
        }
        return false
    }

    func mouseDown(at point: CGPoint) {
        cancel()
        phase = .pressed(point)
    }

    func mouseDragged(to point: CGPoint) {
        switch phase {
        case let .pressed(press) where distance(press, point) >= Self.startDistance:
            let cursor = windowList.cursor() ?? point
            // Under the cursor, or at the press point in case the window lags the cursor. The window
            // just pressed on is in front, so it wins over a window behind that only the cursor is over.
            if let window = windowList.window(at: [cursor, press], excluding: ownPID) {
                phase = .checking(window, press: press, readAt: cursor)
            } else {
                phase = .ignored
            }
        case let .checking(window, press, readAt):
            check(window, press: press, readAt: readAt, cursor: point)
        case let .moving(window):
            // A drag event means the button is held, whatever the last check read.
            buttonUpChecks = 0
            onMoved?(window, point)
        default:
            break
        }
    }

    func mouseUp(at point: CGPoint) {
        if case let .moving(window) = phase {
            onEnded?(window, point)
        }
        becomeIdle()
    }

    /// Forgets the current drag without a drop, for example because Accessibility was revoked.
    func cancel() {
        if case let .moving(window) = phase {
            Log.drag.debug("Window drag cancelled")
            onCancelled?(window)
        }
        becomeIdle()
    }

    // MARK: Private

    private func check(_ window: ListedWindow, press: CGPoint, readAt: CGPoint, cursor eventPoint: CGPoint) {
        guard let bounds = windowList.bounds(of: window.id) else {
            phase = .ignored
            return
        }
        let cursor = windowList.cursor() ?? eventPoint
        if isMove(from: window.bounds, to: bounds) {
            // The window follows the cursor one to one, so it had moved by as much as the cursor when
            // it was read: take that back off to get where it started.
            let before = window.bounds.offsetBy(dx: press.x - readAt.x, dy: press.y - readAt.y)
            let dragged = DraggedWindow(id: window.id, pid: window.pid, frameBeforeDrag: before)
            phase = .moving(dragged)
            buttonCheck = scheduler.schedule(every: Self.buttonCheckInterval, tolerance: 0.05) { [weak self] in
                self?.checkButton()
            }
            Log.drag.debug("Window drag started")
            // Snap areas follow the event's position, like every later drag event.
            onMoveStarted?(dragged, eventPoint)
        } else if distance(readAt, cursor) >= Self.giveUpDistance {
            phase = .ignored
        }
    }

    private func checkButton() {
        guard !isLeftButtonDown() else {
            buttonUpChecks = 0
            return
        }
        buttonUpChecks += 1
        if buttonUpChecks >= Self.buttonUpChecksToCancel {
            cancel()
        }
    }

    private func becomeIdle() {
        phase = .idle
        buttonCheck?.cancel()
        buttonCheck = nil
        buttonUpChecks = 0
    }

    /// Moved by at least a point, and kept its size: dragging the left edge to resize also moves the origin.
    private func isMove(from original: CGRect, to bounds: CGRect) -> Bool {
        let tolerance: CGFloat = 1
        let sameSize = abs(bounds.width - original.width) <= tolerance
            && abs(bounds.height - original.height) <= tolerance
        return sameSize && distance(bounds.origin, original.origin) >= tolerance
    }

    private func distance(_ lhs: CGPoint, _ rhs: CGPoint) -> CGFloat {
        hypot(lhs.x - rhs.x, lhs.y - rhs.y)
    }
}
