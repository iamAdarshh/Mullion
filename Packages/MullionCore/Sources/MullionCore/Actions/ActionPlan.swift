import CoreGraphics

/// Where a window should go, and what to remember about it afterwards.
public struct ActionPlan: Equatable, Sendable {
    /// The target frame in AX space, rounded to whole points.
    public let target: CGRect
    /// The screen the window ends up on. Its visible frame bounds any minimum-size correction.
    public let screen: ScreenGeometry
    /// The snap to remember, or `nil` when the result isn't a tiled action
    /// (in which case any earlier record should be forgotten).
    public let record: SnapRecord?

    public init(target: CGRect, screen: ScreenGeometry, record: SnapRecord?) {
        self.target = target
        self.screen = screen
        self.record = record
    }
}
