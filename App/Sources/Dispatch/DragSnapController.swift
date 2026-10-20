import CoreGraphics
import MullionCore

/// Follows a window drag, works out which snap area the cursor is in and previews where the window
/// will go (PRD §6.4).
///
/// The screens are read once when the drag starts, so a drag never rebuilds them on every mouse event.
@MainActor
final class DragSnapController {
    private let screens: any ScreenProviding
    private let preview: any SnapPreviewing
    private let dragSettings: () -> DragSettings
    private let actionSettings: () -> ActionSettings
    private var dragScreens: [ScreenGeometry] = []
    private var windowFrame = CGRect.zero
    /// The cursor's last position during a window drag; `nil` when no window is being dragged.
    private var cursor: CGPoint?
    private var isSnappingDisabled = false

    /// The area under the cursor, or `nil` outside every area or when no window is being dragged.
    private(set) var match: SnapMatch?

    init(
        screens: any ScreenProviding,
        preview: any SnapPreviewing,
        dragSettings: @escaping () -> DragSettings,
        actionSettings: @escaping () -> ActionSettings
    ) {
        self.screens = screens
        self.preview = preview
        self.dragSettings = dragSettings
        self.actionSettings = actionSettings
    }

    /// - Parameter windowFrame: The dragged window's frame before the drag.
    func dragStarted(windowFrame: CGRect, at cursor: CGPoint) {
        dragScreens = screens.screens
        preview.prepare(for: dragScreens)
        self.windowFrame = windowFrame
        match = nil
        dragMoved(to: cursor)
    }

    func dragMoved(to cursor: CGPoint) {
        self.cursor = cursor
        let next = isSnappingDisabled ? nil : SnapAreaResolver.resolve(
            cursor: cursor, screens: dragScreens, previous: match, settings: dragSettings()
        )
        guard next != match else { return }
        match = next
        Log.drag.debug("Snap area: \(next.map(\.action.rawValue) ?? "none", privacy: .public)")
        showPreview()
    }

    /// Turns snapping off while the user holds ⌥ (PRD §6.4). Takes effect at once, mid-drag: the
    /// preview hides, or comes back when ⌥ is released, without waiting for the mouse to move.
    func setSnappingDisabled(_ disabled: Bool) {
        guard disabled != isSnappingDisabled else { return }
        isSnappingDisabled = disabled
        if let cursor {
            dragMoved(to: cursor)
        }
    }

    /// Forgets the drag without a drop.
    func dragCancelled() {
        finish()
    }

    /// Ends the drag and returns the area it ended in.
    @discardableResult
    func dragEnded(at cursor: CGPoint) -> SnapMatch? {
        dragMoved(to: cursor)
        let result = match
        finish()
        Log.drag.debug("Window drag ended in \(result.map(\.action.rawValue) ?? "no area", privacy: .public)")
        return result
    }

    // MARK: Private

    /// Previews the same rect the action would produce from a shortcut, gaps included (PRD §9 Q1).
    private func showPreview() {
        guard let match,
              let rect = ActionCalculator.targetRect(
                  for: match.action, window: windowFrame, screen: match.screen, settings: actionSettings()
              )
        else {
            preview.hide()
            return
        }
        preview.show(rect, on: match.screen)
    }

    private func finish() {
        match = nil
        cursor = nil
        dragScreens = []
        preview.hide()
    }
}
