import CoreGraphics
import MullionCore

/// Shows where a dragged window will go (PRD §6.4). `OverlayController` is the live implementation;
/// tests use `FakePreview`.
@MainActor
protocol SnapPreviewing: AnyObject {
    /// Shows the preview at `rect` (AX space) on `screen`, hiding it on every other screen.
    func show(_ rect: CGRect, on screen: ScreenGeometry)
    func hide()
}
