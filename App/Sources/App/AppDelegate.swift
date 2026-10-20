import AppKit

/// Creates the long-lived services at launch and connects them.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var accessibility: AccessibilityCoordinator?
    private var menuBar: MenuBarController?
    private var dispatcher: ActionDispatcher?
    private var hotkeys: HotkeyService?
    private var dragMonitor: DragMonitor?
    private var dragSnapper: DragSnapController?

    /// True when the app is hosting unit tests. Skip all UI and permission prompts then,
    /// otherwise CI would hang on the Accessibility prompt.
    private static var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    func applicationDidFinishLaunching(_: Notification) {
        guard !Self.isRunningTests else {
            Log.app.info("Hosting tests; skipping launch setup")
            return
        }

        let accessibility = AccessibilityCoordinator(
            checker: AXPermission(),
            scheduler: TimerScheduler(),
            makeOnboarding: { OnboardingWindowController(onRequestAccess: $0) },
            openSettings: { AXPermission.openSystemSettings() }
        )
        let preferences = Preferences()
        // One queue for every AX call, so a drag and a hotkey can never race on a window (ARCHITECTURE §7).
        let windows = AXQueue()
        let dispatcher = Self.makeDispatcher(windows: windows, preferences: preferences, accessibility: accessibility)
        let menuBar = MenuBarController(isTrusted: accessibility.isTrusted)
        let hotkeys = HotkeyService { [weak dispatcher] action in
            dispatcher?.perform(action)
        }
        let (dragMonitor, dragSnapper) = Self.makeDragToSnap(windows: windows)
        self.accessibility = accessibility
        self.menuBar = menuBar
        self.dispatcher = dispatcher
        self.hotkeys = hotkeys
        self.dragMonitor = dragMonitor
        self.dragSnapper = dragSnapper

        accessibility.onTrustChange = { [weak menuBar, weak hotkeys, weak dragMonitor] trusted in
            menuBar?.setAccessibilityTrusted(trusted)
            hotkeys?.setEnabled(trusted)
            dragMonitor?.setEnabled(trusted)
        }
        menuBar.onMenuWillOpen = { [weak accessibility] in
            accessibility?.refresh()
        }
        menuBar.onGrantAccess = { [weak accessibility] in
            accessibility?.showOnboarding()
        }
        menuBar.onAction = { [weak dispatcher] action in
            dispatcher?.perform(action)
        }

        Log.app.info("Launched, Accessibility trusted: \(accessibility.isTrusted, privacy: .public)")
        hotkeys.start()
        hotkeys.setEnabled(accessibility.isTrusted)
        dragMonitor.setEnabled(accessibility.isTrusted)
        accessibility.start()
    }

    private static func makeDispatcher(
        windows: AXQueue,
        preferences: Preferences,
        accessibility: AccessibilityCoordinator
    ) -> ActionDispatcher {
        ActionDispatcher(
            windows: windows,
            screens: SystemScreens(),
            settings: { preferences.actionSettings },
            isTrusted: { [weak accessibility] in
                // Re-check before every action, so a revocation is noticed right away (PRD §6.9.3).
                accessibility?.refresh()
                return accessibility?.isTrusted ?? false
            },
            frontmostPID: { Self.frontmostOtherAppPID() },
            isProcessRunning: { NSRunningApplication(processIdentifier: $0) != nil }
        )
    }

    /// Connects the mouse monitor to the snap-area tracking (PRD §6.4).
    private static func makeDragToSnap(windows: AXQueue) -> (DragMonitor, DragSnapController) {
        let snapper = DragSnapController(screens: SystemScreens(), settings: { .defaults })
        let tracker = DragTracker(windows: windows, ownPID: ProcessInfo.processInfo.processIdentifier)
        tracker.onMoveStarted = { [weak snapper] _, cursor in snapper?.dragStarted(at: cursor) }
        tracker.onMoved = { [weak snapper] _, cursor in snapper?.dragMoved(to: cursor) }
        tracker.onEnded = { [weak snapper] _, cursor in snapper?.dragEnded(at: cursor) }
        return (DragMonitor(tracker: tracker), snapper)
    }

    func applicationSupportsSecureRestorableState(_: NSApplication) -> Bool {
        true
    }

    /// The frontmost app's pid, or `nil` when that's Mullion itself: never act on our own windows.
    private static func frontmostOtherAppPID() -> pid_t? {
        guard let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier,
              pid != ProcessInfo.processInfo.processIdentifier
        else { return nil }
        return pid
    }
}
