import CoreGraphics

/// A rect expressed as fractions (0…1) of another rect, usually a screen's visible frame.
/// `y` is measured from the top, matching AX space.
public struct UnitRect: Equatable, Hashable, Sendable {
    public var x: CGFloat
    public var y: CGFloat
    public var width: CGFloat
    public var height: CGFloat

    public init(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    /// The whole frame.
    public static let full = UnitRect(x: 0, y: 0, width: 1, height: 1)

    /// The absolute rect this fraction describes inside `frame`.
    public func rect(in frame: CGRect) -> CGRect {
        CGRect(
            x: frame.minX + x * frame.width,
            y: frame.minY + y * frame.height,
            width: width * frame.width,
            height: height * frame.height
        )
    }
}
