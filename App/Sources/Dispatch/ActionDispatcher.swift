import Foundation
import MullionCore
import os

/// Runs window actions: finds the focused window, asks `ActionPlanner` where it goes, moves it,
/// and corrects for apps that refuse the size (AC-2). Hotkeys and the menu both end up here.
@MainActor
final class ActionDispatcher {
    /// Apps that round sizes or enforce aspect ratios are accepted within this many points (ARCHITECTURE §11).
    static let frameTolerance: CGFloat = 2

    private let windows: any WindowControlling
    private let screens: any ScreenProviding
    private let settings: () -> ActionSettings
    private let isTrusted: () -> Bool
    private let frontmostPID: () -> pid_t?
    private let isProcessRunning: (pid_t) -> Bool
    private let store = RestoreStore()
    private let signposter = OSSignposter(subsystem: Log.subsystem, category: "snap")
    /// The action currently running. Each new action waits for it, so two quick key presses
    /// can't interleave their AX reads and writes or their bookkeeping.
    private var tail: Task<Void, Never>?

    /// - Parameters:
    ///   - isTrusted: Re-checks Accessibility trust. Called before every action (PRD §6.9.3).
    ///   - frontmostPID: The frontmost app's pid, or `nil` when it's Mullion itself or there is none.
    ///   - isProcessRunning: Whether an app is still running. Cheap, and needs no AX call.
    init(
        windows: any WindowControlling,
        screens: any ScreenProviding,
        settings: @escaping () -> ActionSettings,
        isTrusted: @escaping () -> Bool,
        frontmostPID: @escaping () -> pid_t?,
        isProcessRunning: @escaping (pid_t) -> Bool
    ) {
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

    /// Queues `action` behind any action still running. Await the returned task to wait for it.
    @discardableResult
    func perform(_ action: WindowAction) -> Task<Void, Never> {
        let previous = tail
        let task = Task {
            await previous?.value
            await run(action)
        }
        tail = task
        return task
    }

    // MARK: Private

    private func run(_ action: WindowAction) async {
        guard isTrusted() else {
            Log.layout.info("Ignoring \(action.rawValue, privacy: .public): Accessibility access is missing")
            return
        }
        guard let pid = frontmostPID() else { return }

        let interval = signposter.beginInterval("Mullion.snap", "\(action.rawValue, privacy: .public)")
        defer { signposter.endInterval("Mullion.snap", interval) }

        do {
            // No focused standard window (desktop, full screen, no windows): do nothing, silently (AC-3, AC-4).
            guard let window = try await windows.focusedWindow(pid: pid) else { return }
            try await apply(action, to: window)
            await forgetClosedWindows(except: window)
        } catch {
            Log.ax.error("\(action.rawValue, privacy: .public) failed: \(String(describing: error), privacy: .public)")
        }
    }

    private func apply(_ action: WindowAction, to window: WindowRef) async throws {
        let frame = try await windows.frame(of: window)
        let context = store.context(for: window, frame: frame)
        guard let plan = ActionPlanner.plan(action, for: context, screens: screens.screens, settings: settings())
        else { return }

        try await windows.setFrame(plan.target, of: window)
        var actual = try await windows.frame(of: window)

        // The app kept a different size (minimum size, fixed size, aspect ratio):
        // put the window at the target's origin and keep it on the target screen (AC-2).
        if !actual.isApproximatelyEqual(to: plan.target, tolerance: Self.frameTolerance) {
            let adjusted = ActionCalculator.reanchored(
                actual: actual, target: plan.target, visibleFrame: plan.screen.visibleFrame
            )
            if !adjusted.isApproximatelyEqual(to: actual, tolerance: Self.frameTolerance) {
                try await windows.setFrame(adjusted, of: window)
                actual = try await windows.frame(of: window)
            }
        }

        if action == .restore {
            store.forget(window)
        } else {
            store.recordMove(of: window, from: frame, snap: plan.record?.with(frame: actual))
        }
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
