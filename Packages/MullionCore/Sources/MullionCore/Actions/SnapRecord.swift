import CoreGraphics

/// What Mullion remembers about the last tiled action it applied to a window.
/// Used to recognise a repeated shortcut (PRD §6.2) and to keep the action on another display (§6.5).
public struct SnapRecord: Equatable, Sendable {
    /// A tiled action (`WindowAction.isTiled`).
    public let action: WindowAction
    /// The repeat-to-cycle step for half actions; `nil` means ½.
    public let halfFraction: CGFloat?
    /// The frame the window ended up with. Store the frame read back from the window, not the
    /// target, so a window with a minimum size still counts as snapped.
    public let frame: CGRect

    public init(action: WindowAction, halfFraction: CGFloat?, frame: CGRect) {
        self.action = action
        self.halfFraction = halfFraction
        self.frame = frame
    }

    /// The same record with the frame the window actually ended up with.
    public func with(frame: CGRect) -> SnapRecord {
        SnapRecord(action: action, halfFraction: halfFraction, frame: frame)
    }
}
