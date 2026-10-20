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
    private let isIgnored: (pid_t) -> Bool
    private var dragScreens: [ScreenGeometry] = []
    private var windowFrame = CGRect.zero
    /// The cursor's last position during a window drag; `nil` when no window is being dragged.
    private var cursor: CGPoint?
    private var isSnappingDisabled = false
    /// The dragged window's app is on the ignore list: nothing snaps for the whole drag.
    private var isIgnoredDrag = false

    /// The area under the cursor, or `nil` outside every area or when no window is being dragged.
    private(set) var match: SnapMatch?

    init(
        screens: any ScreenProviding,
        preview: any SnapPreviewing,
        dragSettings: @escaping () -> DragSettings,
        actionSettings: @escaping () -> ActionSettings,
        isIgnored: @escaping (pid_t) -> Bool
    ) {
        self.screens = screens
        self.preview = preview
        self.dragSettings = dragSettings
        self.actionSettings = actionSettings
        self.isIgnored = isIgnored
    }

    func dragStarted(_ window: DraggedWindow, at cursor: CGPoint) {
        isIgnoredDrag = isIgnored(window.pid)
        if isIgnoredDrag {
            Log.drag.debug("Not snapping: the app is on the ignore list")
        }
        dragScreens = screens.screens
        preview.prepare(for: dragScreens)
        windowFrame = window.frameBeforeDrag
        match = nil
        dragMoved(to: cursor)
    }

    func dragMoved(to cursor: CGPoint) {
        self.cursor = cursor
        let next = isSnappingDisabled || isIgnoredDrag ? nil : SnapAreaResolver.resolve(
            cursor: cursor, screens: dragScreens, previous: match, settings: dragSettings()
        )
        guard next != match else { return }
        match = next
        Log.drag.debug("Snap area: \(next.map(\.action.rawValue) ?? "none", privacy: .public)")
        showPreview()
    }

    /// Turns snapping off while the user holds ⌥ (PRD §6.4). Takes effect mid-drag, without waiting for
    /// the mouse to move: the preview hides, or comes back when ⌥ is released. (While Mullion itself is
    /// the active app, the global monitor doesn't see ⌥ change until the next mouse event.)
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

    /// What a drop does to the window.
    enum Drop: Equatable {
        /// Dropped in a snap area: snap there.
        case snap(SnapMatch)
        /// Dropped outside every area: a snapped window gets its size back (PRD §6.3).
        case free
        /// ⌥ was held or the app is ignored: Mullion leaves the window alone.
        case leaveAlone
    }

    /// Ends the drag and says what the drop does.
    @discardableResult
    func dragEnded(at cursor: CGPoint) -> Drop {
        dragMoved(to: cursor)
        let drop: Drop = if isSnappingDisabled || isIgnoredDrag {
            .leaveAlone
        } else {
            match.map(Drop.snap) ?? .free
        }
        let area = match.map(\.action.rawValue) ?? "no area"
        let reason = isIgnoredDrag ? " (app ignored)" : isSnappingDisabled ? " (⌥ held)" : ""
        Log.drag.debug("Window drag ended in \(area, privacy: .public)\(reason, privacy: .public)")
        finish()
        return drop
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
        isIgnoredDrag = false
        dragScreens = []
        preview.hide()
    }
}
