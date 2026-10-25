import CoreGraphics

/// How a window's frame is written over Accessibility, which sets size and position separately
/// (ARCHITECTURE §5). All frames are in AX space.
public enum FrameWrite {
    /// Which of the two goes first.
    public enum Order: Equatable, Sendable {
        /// Size, then position, then size again. macOS keeps a window's size within its current
        /// display, so this is the order for a window coming from another one.
        case sizeFirst
        /// Position, then size.
        case positionFirst
    }

    /// The order that keeps the window on screen between the writes.
    ///
    /// Resizing a right-half window to the full width in place stretches it past the screen edge, where
    /// apps can cut the resize short and then drop the final one (#16). So on the same screen, whichever
    /// order overflows `visibleFrame` less goes first. A tie keeps size first.
    public static func order(moving window: CGRect, to target: CGRect, within visibleFrame: CGRect) -> Order {
        guard visibleFrame.insetBy(dx: -1, dy: -1).contains(window) else { return .sizeFirst }
        let resizedInPlace = overflow(of: CGRect(origin: window.origin, size: target.size), beyond: visibleFrame)
        let movedFirst = overflow(of: CGRect(origin: target.origin, size: window.size), beyond: visibleFrame)
        return movedFirst + 1 < resizedInPlace ? .positionFirst : .sizeFirst
    }

    /// True when the app kept a smaller size than `target`, so the resize is worth asking for again.
    /// A minimum size only ever makes a window larger, and apps that round sizes stay within 2 pt.
    public static func wasCutShort(_ size: CGSize, target: CGSize) -> Bool {
        size.width < target.width - tolerance || size.height < target.height - tolerance
    }

    // MARK: Private

    private static let tolerance: CGFloat = 2

    /// How far `frame` reaches past each edge of `bounds`, added up.
    private static func overflow(of frame: CGRect, beyond bounds: CGRect) -> CGFloat {
        max(0, bounds.minX - frame.minX) + max(0, frame.maxX - bounds.maxX)
            + max(0, bounds.minY - frame.minY) + max(0, frame.maxY - bounds.maxY)
    }
}
