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
    private var focused: WindowRef?
    private var setFrameError: AXWindowError?

    /// A fresh window ref. Creating an application element makes no IPC call, so any pid works.
    static func makeRef(pid: pid_t) -> WindowRef {
        WindowRef(element: AXUIElementCreateApplication(pid), pid: pid)
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

    func failSetFrame(with error: AXWindowError?) {
        setFrameError = error
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

    func frame(of window: WindowRef) throws -> CGRect {
        guard let fake = windows[window], fake.isAlive else { throw AXWindowError.elementGone }
        return fake.frame
    }

    func setFrame(_ frame: CGRect, of window: WindowRef) throws {
        if let setFrameError {
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
        fake.frame = CGRect(origin: frame.origin, size: size)
        windows[window] = fake
    }

    func isAlive(_ window: WindowRef) -> Bool {
        windows[window]?.isAlive ?? false
    }
}
