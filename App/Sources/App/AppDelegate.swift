import AppKit

/// Wires the menu bar, Accessibility monitoring and onboarding together.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var permission: PermissionMonitor?
    private var menuBar: MenuBarController?
    private var onboarding: OnboardingWindowController?

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

        let permission = PermissionMonitor(checker: AXPermission(), scheduler: TimerScheduler())
        let menuBar = MenuBarController(isTrusted: permission.isTrusted)
        self.permission = permission
        self.menuBar = menuBar

        permission.onChange = { [weak self] trusted in
            self?.accessibilityTrustChanged(trusted)
        }
        menuBar.onMenuWillOpen = { [weak permission] in
            permission?.refresh()
        }
        menuBar.onGrantAccess = { [weak self] in
            self?.showOnboarding()
        }

        Log.app.info("Launched, Accessibility trusted: \(permission.isTrusted, privacy: .public)")
        if permission.isTrusted {
            permission.startPolling(.background)
        } else {
            showOnboarding()
        }
    }

    func applicationSupportsSecureRestorableState(_: NSApplication) -> Bool {
        true
    }

    private func accessibilityTrustChanged(_ trusted: Bool) {
        menuBar?.setAccessibilityTrusted(trusted)
        if trusted {
            // Closing triggers `onClose`, which drops back to background polling.
            onboarding?.close()
        }
    }

    private func showOnboarding() {
        guard let permission else { return }
        if onboarding == nil {
            let controller = OnboardingWindowController { [weak self] in
                self?.requestAccess()
            }
            controller.onClose = { [weak self] in
                self?.onboarding = nil
                self?.permission?.startPolling(.background)
            }
            onboarding = controller
        }
        onboarding?.present()
        permission.startPolling(.onboarding)
    }

    private func requestAccess() {
        guard let permission else { return }
        switch permission.requestTrust() {
        case .alreadyTrusted:
            permission.refresh()
        case .promptShown:
            break
        case .openSettings:
            AXPermission.openSystemSettings()
        }
    }
}
