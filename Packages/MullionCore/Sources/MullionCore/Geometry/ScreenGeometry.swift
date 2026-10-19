import CoreGraphics

/// A display as Core sees it. Every rect is in AX space (see `CoordinateSpace`).
public struct ScreenGeometry: Equatable, Hashable, Sendable, Identifiable {
    /// A stable identifier for the display (the app uses its display UUID).
    public let id: String
    /// The whole display.
    public let frame: CGRect
    /// The display minus the menu bar and Dock. Every action targets this rect.
    public let visibleFrame: CGRect
    /// Points-to-pixels factor (1 or 2). Informational; all geometry is in points.
    public let scale: CGFloat

    public init(id: String, frame: CGRect, visibleFrame: CGRect, scale: CGFloat) {
        self.id = id
        self.frame = frame
        self.visibleFrame = visibleFrame
        self.scale = scale
    }

    /// Portrait screens (height > width) lay thirds and sixths out vertically (PRD §6.1).
    public var isPortrait: Bool {
        frame.height > frame.width
    }
}
