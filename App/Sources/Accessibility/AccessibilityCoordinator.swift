/// Runs the Accessibility permission flow (PRD §6.9): shows onboarding when access is missing,
/// picks the polling rate, and reports trust changes so the menu bar can update.
@MainActor
final class AccessibilityCoordinator {
    /// Called whenever trust changes.
    var onTrustChange: ((Bool) -> Void)?

    var isTrusted: Bool {
        permission.isTrusted
    }

    private let permission: PermissionMonitor
    private let makeOnboarding: (_ onRequestAccess: @escaping () -> Void) -> any OnboardingPresenting
    private let openSettings: () -> Void
    private var onboarding: (any OnboardingPresenting)?

    /// - Parameters:
    ///   - makeOnboarding: Creates the welcome window; its argument is the action for the window's button.
    ///   - openSettings: Opens *Privacy & Security → Accessibility* in System Settings.
    init(
        checker: any AccessibilityTrustChecking,
        scheduler: any RepeatingScheduler,
        makeOnboarding: @escaping (_ onRequestAccess: @escaping () -> Void) -> any OnboardingPresenting,
        openSettings: @escaping () -> Void
    ) {
        permission = PermissionMonitor(checker: checker, scheduler: scheduler)
        self.makeOnboarding = makeOnboarding
        self.openSettings = openSettings
        permission.onChange = { [weak self] trusted in
            self?.trustChanged(trusted)
        }
    }

    /// Call once at launch.
    func start() {
        if permission.isTrusted {
            permission.startPolling(.background)
        } else {
            showOnboarding()
        }
    }

    /// Re-checks trust now, for example when the menu opens.
    func refresh() {
        permission.refresh()
    }

    /// Shows the welcome window (reusing it if it's already open) and polls once per second.
    func showOnboarding() {
        if onboarding == nil {
            let window = makeOnboarding { [weak self] in
                self?.requestAccess()
            }
            window.onClose = { [weak self] in
                self?.onboardingClosed()
            }
            onboarding = window
        }
        onboarding?.present()
        permission.startPolling(.onboarding)
    }

    private func onboardingClosed() {
        onboarding = nil
        permission.startPolling(.background)
    }

    private func trustChanged(_ trusted: Bool) {
        onTrustChange?(trusted)
        if trusted {
            // Closing calls `onboardingClosed`, which drops back to background polling.
            onboarding?.close()
        }
    }

    private func requestAccess() {
        switch permission.requestTrust() {
        case .alreadyTrusted:
            permission.refresh()
        case .promptShown:
            break
        case .openSettings:
            openSettings()
        }
    }
}
