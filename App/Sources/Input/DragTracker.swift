import CoreGraphics

/// Tells a window drag apart from every other mouse drag (ARCHITECTURE §6).
///
/// Window positions come from the window server (`WindowListing`), never from Accessibility: while
/// the user drags a window by its title bar, its app is busy in the drag loop and every AX read times
/// out. A press costs nothing. Once the mouse has moved `startDistance`, the window under the cursor
/// is looked up once (under the cursor, not the press point: the window has already followed the
/// cursor, so a press near its edge may no longer be over it), and its bounds are compared on later
/// events. When the origin moves and the size doesn't, the user is dragging the window. A window
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
        /// `window.bounds` was read when the cursor was at `readAt`, after a press at `press`.
        case checking(ListedWindow, press: CGPoint, readAt: CGPoint)
        case moving(DraggedWindow)
        case ignored
    }

    private let windowList: any WindowListing
    private let ownPID: pid_t
    private var phase = Phase.idle

    /// - Parameter ownPID: Mullion's pid. Its own windows are never snapped.
    init(windowList: any WindowListing, ownPID: pid_t) {
        self.windowList = windowList
        self.ownPID = ownPID
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
            if let window = windowList.window(at: point, excluding: ownPID) {
                phase = .checking(window, press: press, readAt: point)
            } else {
                phase = .ignored
            }
        case let .checking(window, press, readAt):
            check(window, press: press, readAt: readAt, cursor: point)
        case let .moving(window):
            onMoved?(window, point)
        default:
            break
        }
    }

    func mouseUp(at point: CGPoint) {
        if case let .moving(window) = phase {
            onEnded?(window, point)
        }
        phase = .idle
    }

    /// Forgets the current drag without a drop: Accessibility was revoked, or the mouse moved with no
    /// button held, so the release was missed (for example it happened inside Mission Control).
    func cancel() {
        if case let .moving(window) = phase {
            Log.drag.debug("Window drag cancelled")
            onCancelled?(window)
        }
        phase = .idle
    }

    // MARK: Private

    private func check(_ window: ListedWindow, press: CGPoint, readAt: CGPoint, cursor: CGPoint) {
        guard let bounds = windowList.bounds(of: window.id) else {
            phase = .ignored
            return
        }
        if isMove(from: window.bounds, to: bounds) {
            // The window follows the cursor one to one, so it had moved by as much as the cursor when
            // it was read: take that back off to get where it started.
            let before = window.bounds.offsetBy(dx: press.x - readAt.x, dy: press.y - readAt.y)
            let dragged = DraggedWindow(id: window.id, pid: window.pid, frameBeforeDrag: before)
            phase = .moving(dragged)
            Log.drag.debug("Window drag started")
            onMoveStarted?(dragged, cursor)
        } else if distance(readAt, cursor) >= Self.giveUpDistance {
            phase = .ignored
        }
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
