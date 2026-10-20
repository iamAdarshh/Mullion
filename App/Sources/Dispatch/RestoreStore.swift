import CoreGraphics
import MullionCore

/// Per-window memory for the current session (PRD §6.3): the frame from before Mullion first
/// moved the window, and the last tiled action applied to it. Never persisted, because a
/// `WindowRef` is meaningless after its app relaunches.
@MainActor
final class RestoreStore {
    private struct Entry {
        var restoreFrame: CGRect?
        var lastSnap: SnapRecord?
    }

    private var entries: [WindowRef: Entry] = [:]

    /// The windows Mullion currently remembers.
    var windows: [WindowRef] {
        Array(entries.keys)
    }

    /// Everything known about `window`, combined with its current frame.
    func context(for window: WindowRef, frame: CGRect) -> WindowContext {
        let entry = entries[window]
        return WindowContext(frame: frame, lastSnap: entry?.lastSnap, restoreFrame: entry?.restoreFrame)
    }

    /// Records a Mullion-initiated move. `originalFrame` is kept only if this is the first move
    /// since the window was last restored, so *Restore* goes back to where the user had it.
    func recordMove(of window: WindowRef, from originalFrame: CGRect, snap: SnapRecord?) {
        var entry = entries[window] ?? Entry()
        if entry.restoreFrame == nil {
            entry.restoreFrame = originalFrame
        }
        entry.lastSnap = snap
        entries[window] = entry
    }

    /// Keeps the frame from before a move that failed halfway, so *Restore* can still undo it.
    /// The snap record is left alone, so a later repeat or display move still knows the last action.
    func rememberRestoreFrame(_ originalFrame: CGRect, of window: WindowRef) {
        var entry = entries[window] ?? Entry()
        if entry.restoreFrame == nil {
            entry.restoreFrame = originalFrame
        }
        entries[window] = entry
    }

    /// Whether a window of the app with `pid` was still where Mullion last snapped it when a drag began
    /// at `frameBeforeDrag`. Answers without asking the app, so a drop of a window Mullion never
    /// snapped costs no AX call.
    func hasSnap(pid: pid_t, frameBeforeDrag: CGRect) -> Bool {
        entries.contains { window, entry in
            guard window.pid == pid, let snap = entry.lastSnap else { return false }
            return DragAwayPlanner.wasSnapped(at: snap.frame, frameBeforeDrag: frameBeforeDrag)
        }
    }

    /// The frames the app's windows were last snapped to, for diagnostics.
    func snapFrames(pid: pid_t) -> [CGRect] {
        entries.compactMap { window, entry in window.pid == pid ? entry.lastSnap?.frame : nil }
    }

    /// Forgets a window, after it was restored or once it has closed.
    func forget(_ window: WindowRef) {
        entries[window] = nil
    }
}
