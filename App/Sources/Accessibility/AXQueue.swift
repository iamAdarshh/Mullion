import ApplicationServices
import Dispatch

/// Runs every Accessibility read and write, one at a time (ARCHITECTURE §7).
///
/// AX calls are blocking IPC to other apps, so this actor runs on its own serial dispatch queue
/// instead of Swift's shared thread pool. A hung app then only stalls this queue (for at most
/// `AXWindow.messagingTimeout` per call), never the UI or other async work.
actor AXQueue: WindowControlling {
    private let queue = DispatchSerialQueue(label: "io.github.iamadarshh.mullion.ax", qos: .userInteractive)

    nonisolated var unownedExecutor: UnownedSerialExecutor {
        queue.asUnownedSerialExecutor()
    }

    func focusedWindow(pid: pid_t) throws -> WindowRef? {
        try AXWindow.focusedWindow(pid: pid).map { WindowRef(element: $0, pid: pid) }
    }

    func frame(of window: WindowRef) throws -> CGRect {
        try AXWindow.frame(of: window.element)
    }

    func setFrame(_ frame: CGRect, of window: WindowRef) throws {
        try AXWindow.setFrame(frame, of: window.element, pid: window.pid)
    }

    func isAlive(_ window: WindowRef) -> Bool {
        AXWindow.isAlive(window.element)
    }
}
