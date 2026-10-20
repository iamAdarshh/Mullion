import AppKit
import MullionCore

/// Watches mouse presses and drags in other apps with a passive global monitor (ADR-0006) and
/// passes them on to a `DragTracker` in AX space. A global monitor only observes: it can't delay,
/// change or swallow any event, so Mullion can never break the user's mouse.
///
/// It never sees events sent to Mullion itself, so Mullion's own windows are never dragged.
@MainActor
final class DragMonitor {
    private let tracker: DragTracker
    private var monitor: Any?

    init(tracker: DragTracker) {
        self.tracker = tracker
    }

    /// Starts or stops watching. Stopped while Accessibility is revoked, since nothing could be snapped.
    func setEnabled(_ enabled: Bool) {
        if enabled, monitor == nil {
            monitor = NSEvent.addGlobalMonitorForEvents(
                matching: [.leftMouseDown, .leftMouseDragged, .leftMouseUp]
            ) { [weak self] event in
                let type = event.type
                // Global monitor handlers are called on the main thread.
                MainActor.assumeIsolated { self?.handle(type) }
            }
            Log.drag.info("Drag monitor started")
        } else if !enabled, let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
            tracker.reset()
            Log.drag.info("Drag monitor stopped")
        }
    }

    private func handle(_ type: NSEvent.EventType) {
        // The primary screen (with the menu bar) is the flip reference, not the key window's screen (ARCHITECTURE §4).
        guard let primary = NSScreen.screens.first else { return }
        let space = CoordinateSpace(primaryScreenHeight: primary.frame.height)
        let point = space.axPoint(fromAppKit: NSEvent.mouseLocation)
        switch type {
        case .leftMouseDown: tracker.mouseDown(at: point)
        case .leftMouseDragged: tracker.mouseDragged(to: point)
        case .leftMouseUp: tracker.mouseUp(at: point)
        default: break
        }
    }
}
