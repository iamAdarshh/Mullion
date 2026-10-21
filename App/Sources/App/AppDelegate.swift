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
    private var tilingNotice: TilingNoticeCoordinator?
    private var settings: SettingsWindowController?

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
        let (dragMonitor, dragSnapper) = Self.makeDragToSnap(preferences: preferences, dispatcher: dispatcher)
        self.accessibility = accessibility
        self.menuBar = menuBar
        self.dispatcher = dispatcher
        self.hotkeys = hotkeys
        self.dragMonitor = dragMonitor
        self.dragSnapper = dragSnapper
        let tilingNotice = Self.makeTilingNotice(preferences: preferences)
        self.tilingNotice = tilingNotice

        accessibility.onTrustChange = { [weak menuBar, weak hotkeys, weak dragMonitor, weak tilingNotice] trusted in
            menuBar?.setAccessibilityTrusted(trusted)
            hotkeys?.setEnabled(trusted)
            dragMonitor?.setEnabled(trusted)
            if trusted {
                tilingNotice?.showLater()
            }
        }
        Self.connect(menuBar, accessibility: accessibility, dispatcher: dispatcher, preferences: preferences)
        menuBar.onOpenSettings = { [weak self] in self?.showSettings(preferences: preferences) }

        Log.app.info("Launched, Accessibility trusted: \(accessibility.isTrusted, privacy: .public)")
        hotkeys.start()
        hotkeys.setEnabled(accessibility.isTrusted)
        dragMonitor.setEnabled(accessibility.isTrusted)
        accessibility.start()
        if accessibility.isTrusted {
            tilingNotice.showLater()
        }
    }

    /// Opens the Settings window, creating it the first time.
    private func showSettings(preferences: Preferences) {
        let settings = settings ?? SettingsWindowController(preferences: preferences)
        self.settings = settings
        settings.present()
    }

    private static func connect(
        _ menuBar: MenuBarController,
        accessibility: AccessibilityCoordinator,
        dispatcher: ActionDispatcher,
        preferences: Preferences
    ) {
        menuBar.onMenuWillOpen = { [weak accessibility] in
            accessibility?.refresh()
        }
        menuBar.onGrantAccess = { [weak accessibility] in
            accessibility?.showOnboarding()
        }
        menuBar.onAction = { [weak dispatcher] action in
            dispatcher?.perform(action)
        }
        menuBar.ignorableApp = { Self.ignorableFrontmostApp(preferences: preferences) }
        menuBar.onSetIgnored = { ignored, bundleID in
            preferences.setIgnored(ignored, bundleID: bundleID)
        }
    }

    /// The macOS tiling notice (PRD §6.6). Shown once Accessibility is granted, so it never covers
    /// the welcome window.
    private static func makeTilingNotice(preferences: Preferences) -> TilingNoticeCoordinator {
        TilingNoticeCoordinator(
            conflicts: { SystemTilingCheck.live().conflicts() },
            isHidden: { preferences.hidesTilingNotice },
            hide: { preferences.hidesTilingNotice = true },
            presenter: TilingNoticeAlert(),
            openSettings: { TilingNoticeAlert.openSettings() }
        )
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
            isProcessRunning: { NSRunningApplication(processIdentifier: $0) != nil },
            restoresSizeOnDragAway: { preferences.restoresSizeOnDragAway }
        )
    }

    /// Connects the mouse monitor to the snap-area tracking (PRD §6.4).
    private static func makeDragToSnap(
        preferences: Preferences,
        dispatcher: ActionDispatcher
    ) -> (DragMonitor, DragSnapController) {
        let snapper = DragSnapController(
            screens: SystemScreens(),
            preview: OverlayController(),
            dragSettings: { .defaults },
            actionSettings: { preferences.actionSettings },
            isIgnored: { pid in
                NSRunningApplication(processIdentifier: pid)?.bundleIdentifier
                    .map(preferences.ignoredBundleIDs.contains) ?? false
            }
        )
        let tracker = DragTracker(
            windowList: SystemWindowList(),
            ownPID: ProcessInfo.processInfo.processIdentifier,
            scheduler: TimerScheduler(),
            isLeftButtonDown: { NSEvent.pressedMouseButtons & 1 != 0 }
        )
        tracker.onMoveStarted = { [weak snapper] window, cursor in
            snapper?.dragStarted(window, at: cursor)
        }
        tracker.onMoved = { [weak snapper] _, cursor in snapper?.dragMoved(to: cursor) }
        tracker.onEnded = { [weak snapper, weak dispatcher] window, cursor in
            switch snapper?.dragEnded(at: cursor) {
            case let .snap(match): dispatcher?.perform(match.action, onDropped: window, on: match.screen)
            case .free: dispatcher?.restoreSize(ofDropped: window, cursor: cursor)
            case .leaveAlone, nil: break
            }
        }
        tracker.onCancelled = { [weak snapper] _ in snapper?.dragCancelled() }
        let monitor = DragMonitor(tracker: tracker)
        monitor.onOptionKey = { [weak snapper] held in snapper?.setSnappingDisabled(held) }
        return (monitor, snapper)
    }

    func applicationSupportsSecureRestorableState(_: NSApplication) -> Bool {
        true
    }

    /// The frontmost app for the menu's *Ignore* item. Opening Mullion's menu doesn't activate
    /// Mullion, so this is the app the user was just in. `nil` for Mullion itself or an app without
    /// a bundle ID, which the ignore list can't name.
    private static func ignorableFrontmostApp(preferences: Preferences) -> MenuBarController.IgnorableApp? {
        guard let app = NSWorkspace.shared.frontmostApplication,
              app.processIdentifier != ProcessInfo.processInfo.processIdentifier,
              let bundleID = app.bundleIdentifier
        else { return nil }
        return MenuBarController.IgnorableApp(
            bundleID: bundleID,
            name: app.localizedName ?? bundleID,
            isIgnored: preferences.ignoredBundleIDs.contains(bundleID)
        )
    }

    /// The frontmost app's pid, or `nil` when that's Mullion itself: never act on our own windows.
    private static func frontmostOtherAppPID() -> pid_t? {
        guard let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier,
              pid != ProcessInfo.processInfo.processIdentifier
        else { return nil }
        return pid
    }
}
