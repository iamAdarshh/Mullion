import CoreGraphics

/// Reads and moves other apps' windows. `AXQueue` is the live implementation;
/// tests use `FakeWindowController`. All frames are in AX space.
protocol WindowControlling: Sendable {
    /// The focused standard window of the app with `pid`, or `nil` when there is none
    /// (no windows, the desktop, a full-screen window, a panel or other non-standard window).
    func focusedWindow(pid: pid_t) async throws -> WindowRef?
    /// The standard window under `point` (AX space), or `nil` when there is none: the desktop, the
    /// menu bar, the Dock, a panel or a full-screen window.
    func window(at point: CGPoint) async throws -> WindowRef?
    func frame(of window: WindowRef) async throws -> CGRect
    /// Moves and resizes the window. The app may refuse part of it; read the frame back to see.
    func setFrame(_ frame: CGRect, of window: WindowRef) async throws
    /// `false` once the window has closed.
    func isAlive(_ window: WindowRef) async -> Bool
}
