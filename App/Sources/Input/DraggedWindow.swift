import CoreGraphics

/// A window the user is dragging by its title bar, as the window server knows it.
struct DraggedWindow: Equatable, Sendable {
    let id: CGWindowID
    let pid: pid_t
    /// Where the window was before the drag moved it, in AX space.
    let frameBeforeDrag: CGRect
}
