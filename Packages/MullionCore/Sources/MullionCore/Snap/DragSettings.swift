import CoreGraphics

/// User settings for drag-to-snap (PRD §6.4, §6.8 Drag tab).
public struct DragSettings: Equatable, Sendable {
    /// How far from a screen edge the cursor counts as being on it, 1…50 pt.
    public var edgeThickness: CGFloat {
        get { storedEdgeThickness }
        set { (storedEdgeThickness, storedCornerSize) = Self.clamped(newValue, storedCornerSize) }
    }

    /// The side of the square snap area in each corner, 1…100 pt and never less than `edgeThickness`.
    public var cornerSize: CGFloat {
        get { storedCornerSize }
        set { (storedEdgeThickness, storedCornerSize) = Self.clamped(storedEdgeThickness, newValue) }
    }

    /// How far past an area's edge the cursor must move before it counts as having left (AC-5).
    public static let hysteresis: CGFloat = 8

    /// Screens at least this wide for their height split the top edge into sixths (PRD §6.4).
    public static let ultrawideAspectRatio: CGFloat = 21 / 9

    // Each value is clamped against the other, so they are stored privately and set together.
    // `didSet` on both would recurse: setting one from the other's observer runs its observer too.
    private var storedEdgeThickness: CGFloat
    private var storedCornerSize: CGFloat

    public init(edgeThickness: CGFloat = 5, cornerSize: CGFloat = 20) {
        (storedEdgeThickness, storedCornerSize) = Self.clamped(edgeThickness, cornerSize)
    }

    public static let defaults = DragSettings()

    private static func clamped(_ edge: CGFloat, _ corner: CGFloat) -> (CGFloat, CGFloat) {
        let edge = min(max(edge, 1), 50)
        return (edge, min(max(corner, edge), 100))
    }
}
