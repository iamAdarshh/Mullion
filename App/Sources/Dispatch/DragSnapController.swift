import CoreGraphics
import MullionCore

/// Follows a window drag and works out which snap area the cursor is in (PRD §6.4).
///
/// The screens are read once when the drag starts, so a drag never rebuilds them on every mouse event.
@MainActor
final class DragSnapController {
    private let screens: any ScreenProviding
    private let settings: () -> DragSettings
    private var dragScreens: [ScreenGeometry] = []

    /// The area under the cursor, or `nil` outside every area or when no window is being dragged.
    private(set) var match: SnapMatch?

    init(screens: any ScreenProviding, settings: @escaping () -> DragSettings) {
        self.screens = screens
        self.settings = settings
    }

    func dragStarted(at cursor: CGPoint) {
        dragScreens = screens.screens
        match = nil
        dragMoved(to: cursor)
    }

    func dragMoved(to cursor: CGPoint) {
        let next = SnapAreaResolver.resolve(cursor: cursor, screens: dragScreens, previous: match, settings: settings())
        guard next != match else { return }
        match = next
        Log.drag.debug("Snap area: \(next.map(\.action.rawValue) ?? "none", privacy: .public)")
    }

    /// Ends the drag and returns the area it ended in.
    @discardableResult
    func dragEnded(at cursor: CGPoint) -> SnapMatch? {
        dragMoved(to: cursor)
        let result = match
        match = nil
        dragScreens = []
        Log.drag.debug("Window drag ended in \(result.map(\.action.rawValue) ?? "no area", privacy: .public)")
        return result
    }
}
