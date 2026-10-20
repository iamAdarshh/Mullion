import CoreGraphics

/// A window the user has just let go of after dragging it by its title bar.
struct DroppedWindow: Equatable, Sendable {
    let pid: pid_t
    /// Where the window was before the drag moved it, in AX space. Kept for *Restore*.
    let frameBeforeDrag: CGRect
    /// Where the window server says it is now, in AX space. Finds its AX element.
    let frame: CGRect
}
