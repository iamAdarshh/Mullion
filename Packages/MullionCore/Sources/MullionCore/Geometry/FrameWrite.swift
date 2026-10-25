import CoreGraphics

/// How a window's frame is written over Accessibility, which sets size and position separately:
/// a size before the move, the position, then the target size (ARCHITECTURE §5). All frames are in AX space.
public enum FrameWrite {
    /// The size to give the window before moving it, or `nil` when it only needs moving first.
    ///
    /// On one screen, the window first shrinks to the smaller of its size and the target's in each
    /// direction. That size fits both where the window is and where it goes, so no write stretches it
    /// past the screen edge, where apps can cut a resize short and then drop the next one (#16).
    ///
    /// A window outside `visibleFrame` (coming from another display) or a target outside it (Restore or
    /// Grow across two displays) gets the target size first: macOS keeps a window's size within its
    /// current display, so the size is written before and after the move.
    public static func sizeBeforeMove(
        moving window: CGRect,
        to target: CGRect,
        within visibleFrame: CGRect
    ) -> CGSize? {
        let bounds = visibleFrame.insetBy(dx: -1, dy: -1)
        guard bounds.contains(window), bounds.contains(target) else { return target.size }
        let shrunk = CGSize(width: min(window.width, target.width), height: min(window.height, target.height))
        return shrunk == window.size ? nil : shrunk
    }

    /// True when the app kept a smaller size than `target`, so the resize is worth asking for again.
    /// A minimum size only ever makes a window larger. Apps that size windows in whole character
    /// cells (Terminal) or keep a maximum size come out smaller too; asking them again costs one write.
    public static func wasCutShort(_ size: CGSize, target: CGSize) -> Bool {
        size.width < target.width - tolerance || size.height < target.height - tolerance
    }

    // MARK: Private

    private static let tolerance: CGFloat = 2
}
