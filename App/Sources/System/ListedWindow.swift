import CoreGraphics

/// A window as the window server lists it (`CGWindowListCopyWindowInfo`). Bounds are in AX space.
///
/// Read without asking the window's app, so it works while the app is busy in its window-drag loop,
/// when Accessibility reads time out.
struct ListedWindow: Equatable, Sendable {
    let id: CGWindowID
    let pid: pid_t
    let bounds: CGRect
    /// 0 for normal app windows. Menus, the Dock, panels and overlays sit on higher layers.
    let layer: Int
    let alpha: CGFloat

    /// Parses one entry of `CGWindowListCopyWindowInfo`. `nil` when a required key is missing.
    init?(info: [String: Any]) {
        guard let number = info[kCGWindowNumber as String] as? Int,
              let pid = info[kCGWindowOwnerPID as String] as? Int,
              let layer = info[kCGWindowLayer as String] as? Int,
              let boundsInfo = info[kCGWindowBounds as String] as? [String: Any],
              let bounds = CGRect(dictionaryRepresentation: boundsInfo as CFDictionary)
        else { return nil }
        let alpha = info[kCGWindowAlpha as String] as? Double ?? 1
        self.init(id: CGWindowID(number), pid: pid_t(pid), bounds: bounds, layer: layer, alpha: CGFloat(alpha))
    }

    init(id: CGWindowID, pid: pid_t, bounds: CGRect, layer: Int = 0, alpha: CGFloat = 1) {
        self.id = id
        self.pid = pid
        self.bounds = bounds
        self.layer = layer
        self.alpha = alpha
    }

    /// The window the user pressed on: the frontmost visible normal window under any of `points`.
    ///
    /// - Parameters:
    ///   - windows: Front to back, as the window server lists them.
    ///   - points: Where the window may be. The window just pressed on is in front of everything it
    ///     overlaps, so the frontmost window under any of them is that one.
    ///   - ownPID: Mullion's pid. `nil` when Mullion's own window is in front, so it is never dragged.
    static func frontmost(in windows: [ListedWindow], at points: [CGPoint], excluding ownPID: pid_t) -> ListedWindow? {
        guard let window = windows.first(where: { window in
            window.layer == 0 && window.alpha > 0 && points.contains { window.bounds.contains($0) }
        })
        else { return nil }
        return window.pid == ownPID ? nil : window
    }
}
