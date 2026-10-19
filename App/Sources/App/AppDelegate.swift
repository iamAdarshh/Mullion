import AppKit

/// Creates the long-lived services at launch and connects them.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var accessibility: AccessibilityCoordinator?
    private var menuBar: MenuBarController?

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
        let menuBar = MenuBarController(isTrusted: accessibility.isTrusted)
        self.accessibility = accessibility
        self.menuBar = menuBar

        accessibility.onTrustChange = { [weak menuBar] trusted in
            menuBar?.setAccessibilityTrusted(trusted)
        }
        menuBar.onMenuWillOpen = { [weak accessibility] in
            accessibility?.refresh()
        }
        menuBar.onGrantAccess = { [weak accessibility] in
            accessibility?.showOnboarding()
        }

        Log.app.info("Launched, Accessibility trusted: \(accessibility.isTrusted, privacy: .public)")
        accessibility.start()
    }

    func applicationSupportsSecureRestorableState(_: NSApplication) -> Bool {
        true
    }
}
