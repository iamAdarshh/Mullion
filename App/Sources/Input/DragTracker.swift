import CoreGraphics

/// Tells a window drag apart from every other mouse drag (ARCHITECTURE §6).
///
/// Window positions come from the window server (`WindowListing`), never from Accessibility: while
/// the user drags a window by its title bar, its app is busy in the drag loop and every AX read times
/// out. A press costs nothing. Once the mouse has moved `startDistance`, the window under the press
/// point is looked up once, and its bounds are compared on later events: when the origin moves and
/// the size doesn't, the user is dragging the window. A window that hasn't moved by the time the
/// cursor has travelled `giveUpDistance` means text selection, a scrollbar or a resize, and the rest
/// of that drag is ignored without further reads (test-matrix case 15).
///
/// All points are in AX space.
@MainActor
final class DragTracker {
    /// How far the mouse moves before the window under it is looked up. Filters out plain clicks.
    static let startDistance: CGFloat = 4
    /// How far the cursor may move without the window moving before the drag is ignored.
    static let giveUpDistance: CGFloat = 30

    /// The user started dragging a window. Passes the cursor.
    var onMoveStarted: ((ListedWindow, CGPoint) -> Void)?
    /// The cursor moved while dragging a window.
    var onMoved: ((ListedWindow, CGPoint) -> Void)?
    /// The user let go of a window they were dragging.
    var onEnded: ((ListedWindow, CGPoint) -> Void)?

    private enum Phase {
        case idle
        case pressed(CGPoint)
        /// `window.bounds` was read when the cursor was at `readAt`; later reads are compared with it.
        case checking(ListedWindow, readAt: CGPoint)
        case moving(ListedWindow)
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

    func mouseDown(at point: CGPoint) {
        phase = .pressed(point)
    }

    func mouseDragged(to point: CGPoint) {
        switch phase {
        case let .pressed(start) where distance(start, point) >= Self.startDistance:
            if let window = windowList.window(at: start, excluding: ownPID) {
                phase = .checking(window, readAt: point)
            } else {
                phase = .ignored
            }
        case let .checking(window, readAt):
            guard let bounds = windowList.bounds(of: window.id) else {
                phase = .ignored
                return
            }
            if isMove(from: window.bounds, to: bounds) {
                phase = .moving(window)
                Log.drag.debug("Window drag started")
                onMoveStarted?(window, point)
            } else if distance(readAt, point) >= Self.giveUpDistance {
                phase = .ignored
            }
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
        reset()
    }

    /// Forgets the current drag without ending it, for example when Accessibility is revoked.
    func reset() {
        phase = .idle
    }

    // MARK: Private

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
