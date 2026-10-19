import AppKit

/// Creates the long-lived services at launch and connects them.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var accessibility: AccessibilityCoordinator?
    private var menuBar: MenuBarController?
    private var dispatcher: ActionDispatcher?
    private var hotkeys: HotkeyService?

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
        let dispatcher = ActionDispatcher(
            windows: AXQueue(),
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
        let menuBar = MenuBarController(isTrusted: accessibility.isTrusted)
        let hotkeys = HotkeyService { [weak dispatcher] action in
            dispatcher?.perform(action)
        }
        self.accessibility = accessibility
        self.menuBar = menuBar
        self.dispatcher = dispatcher
        self.hotkeys = hotkeys

        accessibility.onTrustChange = { [weak menuBar] trusted in
            menuBar?.setAccessibilityTrusted(trusted)
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
        accessibility.start()
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
