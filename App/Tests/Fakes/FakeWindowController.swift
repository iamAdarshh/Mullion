import ApplicationServices
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
    private(set) var windowAtCalls = 0
    private(set) var frameCalls = 0
    /// The pid of every window `isAlive` was asked about, in order.
    private(set) var isAliveCalls: [pid_t] = []
    private var focused: WindowRef?
    private var setFrameError: AXWindowError?
    private var resizesBeforeFailing = false

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

    /// Moves or resizes a window the way the user would, without recording a `setFrame` call.
    func userChange(_ window: WindowRef, to frame: CGRect) {
        windows[window]?.frame = frame
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

    /// The first live window whose frame contains `point`.
    func window(at point: CGPoint) throws -> WindowRef? {
        windowAtCalls += 1
        return windows.first { $0.value.isAlive && $0.value.frame.contains(point) }?.key
    }

    func frame(of window: WindowRef) throws -> CGRect {
        frameCalls += 1
        guard let fake = windows[window], fake.isAlive else { throw AXWindowError.elementGone }
        return fake.frame
    }

    func setFrame(_ frame: CGRect, of window: WindowRef) throws {
        if let setFrameError, !resizesBeforeFailing {
            throw setFrameError
        }
        guard var fake = windows[window], fake.isAlive else { throw AXWindowError.elementGone }
        setFrameCalls.append(frame)
        let size = fake.isResizable
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
