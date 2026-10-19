import CoreGraphics

public extension CGRect {
    /// Area in square points; 0 for a null or empty rect.
    var area: CGFloat {
        isNull ? 0 : width * height
    }

    /// Rounds each *edge* to a whole point. Rounding edges rather than sizes keeps
    /// neighbouring tiles touching exactly (thirds of 2560 pt become 853 + 854 + 853).
    func roundedToEdges() -> CGRect {
        let minX = minX.rounded()
        let minY = minY.rounded()
        return CGRect(x: minX, y: minY, width: maxX.rounded() - minX, height: maxY.rounded() - minY)
    }

    /// Moves the rect inside `bounds`, shrinking it first if it is larger than `bounds`.
    func clamped(to bounds: CGRect) -> CGRect {
        let size = CGSize(width: min(width, bounds.width), height: min(height, bounds.height))
        return CGRect(origin: origin, size: size).movedInside(bounds)
    }

    /// Moves the rect inside `bounds` without changing its size. A dimension larger than
    /// `bounds` is aligned to the leading (left or top) edge of `bounds`.
    func movedInside(_ bounds: CGRect) -> CGRect {
        func position(_ value: CGFloat, length: CGFloat, lower: CGFloat, upper: CGFloat) -> CGFloat {
            guard length <= upper - lower else { return lower }
            return Swift.min(Swift.max(value, lower), upper - length)
        }
        return CGRect(
            x: position(minX, length: width, lower: bounds.minX, upper: bounds.maxX),
            y: position(minY, length: height, lower: bounds.minY, upper: bounds.maxY),
            width: width,
            height: height
        )
    }

    /// True when origin and size each differ by at most `tolerance` points.
    func isApproximatelyEqual(to other: CGRect, tolerance: CGFloat) -> Bool {
        abs(minX - other.minX) <= tolerance
            && abs(minY - other.minY) <= tolerance
            && abs(width - other.width) <= tolerance
            && abs(height - other.height) <= tolerance
    }

    /// Distance from `point` to the nearest point of the rect; 0 when the point is inside.
    func distance(to point: CGPoint) -> CGFloat {
        let deltaX = Swift.max(minX - point.x, 0, point.x - maxX)
        let deltaY = Swift.max(minY - point.y, 0, point.y - maxY)
        return (deltaX * deltaX + deltaY * deltaY).squareRoot()
    }
}
