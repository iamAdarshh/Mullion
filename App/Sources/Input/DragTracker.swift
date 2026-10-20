import CoreGraphics

/// Tells a window drag apart from every other mouse drag (ARCHITECTURE §6).
///
/// A mouse press costs nothing: a frozen app under the cursor must not slow down every click. Once
/// the mouse has moved `startDistance`, the window under the press point is looked up once and its
/// frame read. Later frames are compared with that one, one AX read at a time: when the origin moves
/// and the size doesn't, the user is dragging the window. A window that hasn't moved by the time the
/// cursor has travelled `giveUpDistance` means text selection, a scrollbar or a resize, and the rest
/// of that drag is ignored without further AX calls (test-matrix case 15).
///
/// All points are in AX space.
@MainActor
final class DragTracker {
    /// How far the mouse moves before the window under it is looked up. Filters out plain clicks.
    static let startDistance: CGFloat = 4
    /// How far the cursor may move without the window moving before the drag is ignored.
    static let giveUpDistance: CGFloat = 30

    /// The user started dragging a window. Passes the cursor.
    var onMoveStarted: ((WindowRef, CGPoint) -> Void)?
    /// The cursor moved while dragging a window.
    var onMoved: ((WindowRef, CGPoint) -> Void)?
    /// The user let go of a window they were dragging.
    var onEnded: ((WindowRef, CGPoint) -> Void)?

    private enum Phase {
        case idle
        case pressed(CGPoint)
        case identifying
        /// `original` is the frame read at `readAt`; later reads are compared with it.
        case checking(WindowRef, original: CGRect, readAt: CGPoint)
        case moving(WindowRef)
        case ignored
    }

    private let windows: any WindowControlling
    private let ownPID: pid_t
    private var phase = Phase.idle
    private var cursor = CGPoint.zero
    /// Bumped by every press and release, so an AX answer that arrives after its drag ended is dropped.
    private var generation = 0
    private var isChecking = false

    /// - Parameter ownPID: Mullion's pid. Its own windows are never snapped.
    init(windows: any WindowControlling, ownPID: pid_t) {
        self.windows = windows
        self.ownPID = ownPID
    }

    func mouseDown(at point: CGPoint) {
        reset()
        phase = .pressed(point)
        cursor = point
    }

    /// Returns the AX work this event started, if any, so tests can wait for it.
    @discardableResult
    func mouseDragged(to point: CGPoint) -> Task<Void, Never>? {
        cursor = point
        switch phase {
        case let .pressed(start) where distance(start, point) >= Self.startDistance:
            phase = .identifying
            return identify(at: start)
        case let .checking(window, original, readAt) where !isChecking:
            return check(window, original: original, readAt: readAt)
        case let .moving(window):
            onMoved?(window, point)
        default:
            break
        }
        return nil
    }

    func mouseUp(at point: CGPoint) {
        if case let .moving(window) = phase {
            onEnded?(window, point)
        }
        reset()
    }

    /// Forgets the current drag without ending it, for example when Accessibility is revoked.
    func reset() {
        generation += 1
        phase = .idle
        isChecking = false
    }

    // MARK: Private

    private func identify(at start: CGPoint) -> Task<Void, Never> {
        let generation = generation
        return Task {
            do {
                guard let window = try await windows.window(at: start), window.pid != ownPID else {
                    ignore(generation)
                    return
                }
                let frame = try await windows.frame(of: window)
                guard generation == self.generation else { return }
                phase = .checking(window, original: frame, readAt: cursor)
            } catch {
                Log.drag.debug("Couldn't identify the dragged window: \(String(describing: error), privacy: .public)")
                ignore(generation)
            }
        }
    }

    private func check(_ window: WindowRef, original: CGRect, readAt: CGPoint) -> Task<Void, Never> {
        isChecking = true
        let generation = generation
        return Task {
            do {
                let frame = try await windows.frame(of: window)
                guard generation == self.generation else { return }
                isChecking = false
                if isMove(from: original, to: frame) {
                    phase = .moving(window)
                    Log.drag.debug("Window drag started")
                    onMoveStarted?(window, cursor)
                } else if distance(readAt, cursor) >= Self.giveUpDistance {
                    phase = .ignored
                }
            } catch {
                Log.drag.debug("Couldn't read the dragged window: \(String(describing: error), privacy: .public)")
                ignore(generation)
            }
        }
    }

    private func ignore(_ generation: Int) {
        guard generation == self.generation else { return }
        phase = .ignored
        isChecking = false
    }

    /// Moved by at least a point, and kept its size: dragging the left edge to resize also moves the origin.
    private func isMove(from original: CGRect, to frame: CGRect) -> Bool {
        let tolerance: CGFloat = 1
        let sameSize = abs(frame.width - original.width) <= tolerance
            && abs(frame.height - original.height) <= tolerance
        return sameSize && distance(frame.origin, original.origin) >= tolerance
    }

    private func distance(_ lhs: CGPoint, _ rhs: CGPoint) -> CGFloat {
        hypot(lhs.x - rhs.x, lhs.y - rhs.y)
    }
}
