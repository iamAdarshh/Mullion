import CoreGraphics

/// What Mullion knows about one window when an action runs.
public struct WindowContext: Equatable, Sendable {
    /// The window's current frame, in AX space.
    public var frame: CGRect
    /// The last tiled action Mullion applied to this window, if any.
    public var lastSnap: SnapRecord?
    /// The frame saved before Mullion first moved this window, if any (PRD §6.3).
    public var restoreFrame: CGRect?

    public init(frame: CGRect, lastSnap: SnapRecord? = nil, restoreFrame: CGRect? = nil) {
        self.frame = frame
        self.lastSnap = lastSnap
        self.restoreFrame = restoreFrame
    }
}
