import CoreGraphics

/// Reads window positions from the window server. `SystemWindowList` is the live implementation;
/// tests use `FakeWindowList`.
@MainActor
protocol WindowListing {
    /// The frontmost visible normal window under any of `points` (AX space), or `nil` over the desktop
    /// or one of Mullion's own windows.
    func window(at points: [CGPoint], excluding ownPID: pid_t) -> ListedWindow?
    /// The window's current bounds, or `nil` once it has closed.
    func bounds(of id: CGWindowID) -> CGRect?
    /// Where the cursor is now (AX space). Read next to a window read, because the window server moves
    /// a dragged window before Mullion handles the event that moved it: the event's own position lags.
    func cursor() -> CGPoint?
}
