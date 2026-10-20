import Foundation
import MullionCore
import os

/// Runs window actions: finds the window, asks `ActionPlanner` where it goes, moves it, and corrects
/// for apps that refuse the size (AC-2). Hotkeys and the menu act on the focused window; drag to snap
/// acts on the window that was dropped.
@MainActor
final class ActionDispatcher {
    /// Apps that round sizes or enforce aspect ratios are accepted within this many points (ARCHITECTURE §11).
    static let frameTolerance: CGFloat = 2
    /// How long to wait before asking a dropped window's app a second time. It may still be leaving
    /// its window-drag loop when the mouse button comes up.
    static let dropRetryDelay = Duration.milliseconds(50)

    /// One move to make, and the window it is made on.
    private struct Request {
        /// Names the move in logs and signposts.
        let name: String
        /// Finds the window. `nil` means there is nothing to act on, silently (AC-3, AC-4).
        let findWindow: () async throws -> WindowRef?
        /// Where the window goes, given what Mullion knows about it. `nil` leaves it alone.
        let plan: (WindowContext) -> ActionPlan?
        /// The frame *Restore* goes back to, when it isn't the window's frame as the move starts.
        var restoreFrame: CGRect?
        /// Forget the window afterwards instead of recording the move: it is back to how the user had it.
        var forgetsWindow = false
    }

    private let windows: any WindowControlling
    private let screens: any ScreenProviding
    private let settings: () -> ActionSettings
    private let isTrusted: () -> Bool
    private let frontmostPID: () -> pid_t?
    private let isProcessRunning: (pid_t) -> Bool
    private let retryDelay: Duration
    private let restoresSizeOnDragAway: () -> Bool
    private let store = RestoreStore()
    private let signposter = OSSignposter(subsystem: Log.subsystem, category: "snap")
    /// The action currently running. Each new action waits for it, so two quick key presses
    /// can't interleave their AX reads and writes or their bookkeeping.
    private var tail: Task<Void, Never>?

    /// - Parameters:
    ///   - isTrusted: Re-checks Accessibility trust. Called before every action (PRD §6.9.3).
    ///   - frontmostPID: The frontmost app's pid, or `nil` when it's Mullion itself or there is none.
    ///   - isProcessRunning: Whether an app is still running. Cheap, and needs no AX call.
    ///   - retryDelay: How long to wait before looking up a dropped window again.
    ///   - restoresSizeOnDragAway: Whether a snapped window dragged away gets its size back (PRD §6.3).
    init(
        windows: any WindowControlling,
        screens: any ScreenProviding,
        settings: @escaping () -> ActionSettings,
        isTrusted: @escaping () -> Bool,
        frontmostPID: @escaping () -> pid_t?,
        isProcessRunning: @escaping (pid_t) -> Bool,
        retryDelay: Duration = ActionDispatcher.dropRetryDelay,
        restoresSizeOnDragAway: @escaping () -> Bool = { true }
    ) {
        self.retryDelay = retryDelay
        self.restoresSizeOnDragAway = restoresSizeOnDragAway
        self.windows = windows
        self.screens = screens
        self.settings = settings
        self.isTrusted = isTrusted
        self.frontmostPID = frontmostPID
        self.isProcessRunning = isProcessRunning
    }

    /// The windows Mullion currently remembers a restore frame or snap for.
    var rememberedWindows: [WindowRef] {
        store.windows
    }

    /// Runs `action` on the focused window, queued behind any action still running. Await the
    /// returned task to wait for it.
    @discardableResult
    func perform(_ action: WindowAction) -> Task<Void, Never> {
        enqueue(Request(
            name: action.rawValue,
            findWindow: { [windows, frontmostPID] in
                // No focused standard window (desktop, full screen, no windows): nothing to do (AC-3, AC-4).
                guard let pid = frontmostPID() else { return nil }
                return try await windows.focusedWindow(pid: pid)
            },
            plan: { [screens, settings] context in
                ActionPlanner.plan(action, for: context, screens: screens.screens, settings: settings())
            },
            forgetsWindow: action == .restore
        ))
    }

    /// Snaps a window the user dropped into a snap area on `screen` (PRD §6.4). *Restore* then puts it
    /// back where it was before the drag, or, if Mullion had already snapped it, before that first snap.
    @discardableResult
    func perform(
        _ action: WindowAction,
        onDropped window: DroppedWindow,
        on screen: ScreenGeometry
    ) -> Task<Void, Never> {
        enqueue(Request(
            name: action.rawValue,
            findWindow: { [weak self] in try await self?.droppedWindow(window) },
            // Only the drop's screen, so a window still mostly on the neighbouring display snaps where
            // the preview showed it.
            plan: { [settings] context in
                ActionPlanner.plan(action, for: context, screens: [screen], settings: settings())
            },
            restoreFrame: window.frameBeforeDrag
        ))
    }

    /// Gives a snapped window that was dragged away and dropped outside every snap area its size from
    /// before the snap back, under the cursor (PRD §6.3). Done at the drop: during the drag the app is
    /// busy in its window-drag loop and wouldn't answer. Windows Mullion never snapped cost no AX call.
    @discardableResult
    func restoreSize(ofDropped window: DroppedWindow, cursor: CGPoint) -> Task<Void, Never> {
        guard restoresSizeOnDragAway(),
              store.hasSnap(pid: window.pid, frameBeforeDrag: window.frameBeforeDrag)
        else { return Task {} }
        return enqueue(Request(
            name: "restoreSizeAfterDrag",
            findWindow: { [weak self] in try await self?.droppedWindow(window) },
            plan: { [screens] context in
                DragAwayPlanner.plan(
                    for: context, frameBeforeDrag: window.frameBeforeDrag, cursor: cursor, screens: screens.screens
                )
            },
            forgetsWindow: true
        ))
    }

    // MARK: Private

    private func enqueue(_ request: Request) -> Task<Void, Never> {
        let previous = tail
        let task = Task {
            await previous?.value
            await run(request)
        }
        tail = task
        return task
    }

    private func run(_ request: Request) async {
        let name = request.name
        guard isTrusted() else {
            Log.layout.info("Ignoring \(name, privacy: .public): Accessibility access is missing")
            return
        }

        let interval = signposter.beginInterval("Mullion.snap", "\(name, privacy: .public)")
        defer { signposter.endInterval("Mullion.snap", interval) }

        do {
            guard let window = try await request.findWindow() else { return }
            try await apply(request, to: window)
            await forgetClosedWindows(except: window)
        } catch let error as AXWindowError where error.isRoutine {
            // The window closed mid-action, or the app is busy. Not worth keeping on disk.
            Log.ax.info("\(name, privacy: .public) skipped: \(String(describing: error), privacy: .public)")
        } catch {
            Log.ax.error("\(name, privacy: .public) failed: \(String(describing: error), privacy: .public)")
        }
    }

    /// The AX element of a dropped window, matched by its frame. Asks once more if the app is still busy.
    private func droppedWindow(_ dropped: DroppedWindow) async throws -> WindowRef? {
        let find = { [windows] in
            try await windows.window(pid: dropped.pid, matching: dropped.frame, tolerance: Self.frameTolerance)
        }
        let found: WindowRef?
        do {
            found = try await find()
        } catch AXWindowError.appNotResponding {
            try? await Task.sleep(for: retryDelay)
            found = try await find()
        }
        if found == nil {
            Log.drag.info("The dropped window has no matching AX window; not snapping")
        }
        return found
    }

    private func apply(_ request: Request, to window: WindowRef) async throws {
        let current = try await windows.frame(of: window)
        let originalFrame = request.restoreFrame ?? current
        guard let plan = request.plan(store.context(for: window, frame: current)) else { return }

        var moved = false
        let actual: CGRect
        do {
            try await windows.setFrame(plan.target, of: window)
            moved = true
            actual = try await correctedFrame(of: window, plan: plan)
        } catch {
            // The window changed before the app gave up (for example resized, then timed out on the move):
            // keep where it was, so Restore can still put it back (PRD §6.3). A failure that changed
            // nothing leaves the store as it was.
            if !request.forgetsWindow, moved || (error as? AXWindowError)?.changedTheWindow == true {
                store.rememberRestoreFrame(originalFrame, of: window)
            }
            throw error
        }

        if request.forgetsWindow {
            store.forget(window)
        } else {
            store.recordMove(of: window, from: originalFrame, snap: plan.record?.with(frame: actual))
        }
    }

    /// Reads the frame back after a move and corrects it when the app kept a different size.
    private func correctedFrame(of window: WindowRef, plan: ActionPlan) async throws -> CGRect {
        var actual = try await windows.frame(of: window)

        // The app kept a different size (minimum size, fixed size, aspect ratio): put the window at
        // the target's origin and, unless the target spanned displays, keep it on the target screen (AC-2).
        if !actual.isApproximatelyEqual(to: plan.target, tolerance: Self.frameTolerance) {
            let adjusted = ActionCalculator.reanchored(
                actual: actual, target: plan.target, visibleFrame: plan.screen.visibleFrame
            )
            if !adjusted.isApproximatelyEqual(to: actual, tolerance: Self.frameTolerance) {
                try await windows.setFrame(adjusted, of: window)
                actual = try await windows.frame(of: window)
            }
        }
        return actual
    }

    /// Drops windows that have closed since they were moved (PRD §6.3).
    ///
    /// Windows of apps that have quit are dropped without any AX call. Only windows of the app
    /// just acted on are re-checked over AX: that app has just answered, so the check is fast.
    /// Other running apps are never queried here, so one frozen app can't slow down every hotkey
    /// (each AX call to it could take the full messaging timeout). Their closed windows are
    /// dropped the next time Mullion acts on that app, or when it quits.
    private func forgetClosedWindows(except current: WindowRef) async {
        for window in store.windows where window != current {
            if !isProcessRunning(window.pid) {
                store.forget(window)
            } else if window.pid == current.pid, await !windows.isAlive(window) {
                store.forget(window)
            }
        }
    }
}
