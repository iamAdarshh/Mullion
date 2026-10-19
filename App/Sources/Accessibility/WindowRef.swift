import ApplicationServices

/// A handle to another app's window, valid for this session only (never persist it: it changes
/// when the app relaunches).
///
/// `@unchecked Sendable` is safe here: `AXUIElement` is an immutable CF reference that is only
/// ever *used* (read or written through) on `AXQueue`. Other actors just pass it along and compare it.
struct WindowRef: @unchecked Sendable, Hashable {
    let element: AXUIElement
    let pid: pid_t

    /// Two refs are the same window when the elements are `CFEqual` (ADR-0003).
    static func == (lhs: WindowRef, rhs: WindowRef) -> Bool {
        lhs.pid == rhs.pid && CFEqual(lhs.element, rhs.element)
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(pid)
        hasher.combine(CFHash(element))
    }
}
