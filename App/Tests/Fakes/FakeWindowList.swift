import CoreGraphics
@testable import Mullion

/// An in-memory window server. Windows are listed front to back, and the user can move them.
@MainActor
final class FakeWindowList: WindowListing {
    private(set) var windows: [ListedWindow] = []
    /// How many times anything was read.
    private(set) var reads = 0
    /// Where the window server says the cursor is. `nil` makes the tracker use the event's position,
    /// as if the event arrived the moment it happened.
    var cursorPosition: CGPoint?

    func add(_ window: ListedWindow) {
        windows.append(window)
    }

    /// Moves or resizes a window the way the user would.
    func userChange(_ id: CGWindowID, to bounds: CGRect) {
        guard let index = windows.firstIndex(where: { $0.id == id }) else { return }
        let old = windows[index]
        windows[index] = ListedWindow(id: id, pid: old.pid, bounds: bounds, layer: old.layer, alpha: old.alpha)
    }

    func close(_ id: CGWindowID) {
        windows.removeAll { $0.id == id }
    }

    func window(at point: CGPoint, excluding ownPID: pid_t) -> ListedWindow? {
        reads += 1
        return ListedWindow.frontmost(in: windows, at: point, excluding: ownPID)
    }

    func bounds(of id: CGWindowID) -> CGRect? {
        reads += 1
        return windows.first { $0.id == id }?.bounds
    }

    func cursor() -> CGPoint? {
        cursorPosition
    }
}
