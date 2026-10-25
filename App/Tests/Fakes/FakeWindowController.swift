import ApplicationServices
import MullionCore
@testable import Mullion

/// An in-memory stand-in for `AXQueue`. Windows behave like real apps: they enforce a minimum
/// size, can refuse resizing entirely, can close, and can fail with an AX error.
actor FakeWindowController: WindowControlling {
    struct Window {
        var frame: CGRect
        var minimumSize: CGSize = .zero
        var isResizable = true
        var isAlive = true
    }

    private(set) var windows: [WindowRef: Window] = [:]
    private(set) var setFrameCalls: [CGRect] = []
    private(set) var focusedWindowCalls = 0
    /// The pid of every window `isAlive` was asked about, in order.
    private(set) var isAliveCalls: [pid_t] = []
    /// How many times a dropped window was looked up.
    private(set) var windowLookups = 0
    private var focused: WindowRef?
    private var lookupErrors: [AXWindowError] = []
    private var setFrameError: AXWindowError?
    private var resizesBeforeFailing = false
    private var droppedResizes = 0

    /// A fresh window ref. Creating an application element makes no IPC call, so any pid works.
    /// Pass `second: true` for another window of the same app (it uses a different element).
    static func makeRef(pid: pid_t, second: Bool = false) -> WindowRef {
        WindowRef(element: second ? AXUIElementCreateSystemWide() : AXUIElementCreateApplication(pid), pid: pid)
    }

    func add(_ window: WindowRef, frame: CGRect, minimumSize: CGSize = .zero, isResizable: Bool = true) {
        windows[window] = Window(frame: frame, minimumSize: minimumSize, isResizable: isResizable)
    }

    func focus(_ window: WindowRef?) {
        focused = window
    }

    func close(_ window: WindowRef) {
        windows[window]?.isAlive = false
    }

    /// Makes `setFrame` throw `error`. With `afterResizing`, the window takes the new size first and
    /// keeps its old position, like a real app that times out between the size and position calls,
    /// and the error is wrapped in `incompleteMove` as `AXWindow` does.
    func failSetFrame(with error: AXWindowError?, afterResizing: Bool = false) {
        setFrameError = error
        resizesBeforeFailing = afterResizing
    }

    /// Makes the next `count` calls to `setFrame` move the window but keep its size, like an app that
    /// drops the resize after the move (#16).
    func dropResizes(_ count: Int = 1) {
        droppedResizes = count
    }

    /// Makes the next window lookups throw these errors, one per lookup.
    func failWindowLookups(with errors: [AXWindowError]) {
        lookupErrors = errors
    }

    func frame(ofWindow window: WindowRef) -> CGRect? {
        windows[window]?.frame
    }

    // MARK: WindowControlling

    func focusedWindow(pid: pid_t) throws -> WindowRef? {
        focusedWindowCalls += 1
        guard let focused, focused.pid == pid else { return nil }
        return focused
    }

    func window(pid: pid_t, matching frame: CGRect, tolerance: CGFloat) throws -> WindowRef? {
        windowLookups += 1
        if !lookupErrors.isEmpty {
            throw lookupErrors.removeFirst()
        }
        // Like `AXWindow`: the focused (main) window if it matches, then any other window that does,
        // then the focused window if its app nudged it a little.
        let alive = windows.filter { $0.key.pid == pid && $0.value.isAlive }
        let main = focused.flatMap { ref in alive[ref].map { (ref, $0.frame) } }
        if let main, main.1.isApproximatelyEqual(to: frame, tolerance: tolerance) {
            return main.0
        }
        if let other = alive.first(where: { $0.value.frame.isApproximatelyEqual(to: frame, tolerance: tolerance) }) {
            return other.key
        }
        if let main, AXWindow.isNudged(main.1, from: frame, tolerance: tolerance) {
            return main.0
        }
        return nil
    }

    func frame(of window: WindowRef) throws -> CGRect {
        guard let fake = windows[window], fake.isAlive else { throw AXWindowError.elementGone }
        return fake.frame
    }

    func setFrame(_ frame: CGRect, of window: WindowRef) throws {
        if let setFrameError, !resizesBeforeFailing {
            throw setFrameError
        }
        guard var fake = windows[window], fake.isAlive else { throw AXWindowError.elementGone }
        setFrameCalls.append(frame)
        let dropsResize = droppedResizes > 0
        droppedResizes = max(droppedResizes - 1, 0)
        let size = fake.isResizable && !dropsResize
            ? CGSize(
                width: max(frame.width, fake.minimumSize.width),
                height: max(frame.height, fake.minimumSize.height)
            )
            : fake.frame.size
        if let setFrameError {
            fake.frame.size = size
            windows[window] = fake
            throw AXWindowError.incompleteMove(setFrameError)
        }
        fake.frame = CGRect(origin: frame.origin, size: size)
        windows[window] = fake
    }

    func isAlive(_ window: WindowRef) -> Bool {
        isAliveCalls.append(window.pid)
        return windows[window]?.isAlive ?? false
    }
}
