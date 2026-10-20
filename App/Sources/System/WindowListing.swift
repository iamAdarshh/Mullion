import CoreGraphics

/// Reads window positions from the window server. `SystemWindowList` is the live implementation;
/// tests use `FakeWindowList`.
@MainActor
protocol WindowListing {
    /// The frontmost visible normal window under `point` (AX space), or `nil` over the desktop or
    /// one of Mullion's own windows.
    func window(at point: CGPoint, excluding ownPID: pid_t) -> ListedWindow?
    /// The window's current bounds, or `nil` once it has closed.
    func bounds(of id: CGWindowID) -> CGRect?
}
